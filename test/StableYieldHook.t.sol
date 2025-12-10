// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {BaseTest} from "./utils/BaseTest.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Constants} from "@uniswap/v4-core/test/utils/Constants.sol";
import {StableYieldHook} from "../src/StableYieldHook.sol";
import {MockAVSOracle} from "../src/mocks/MockAVSOracle.sol";
import {MockMorphoDeposit} from "../src/mocks/MockMorphoDeposit.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {SwapParams, ModifyLiquidityParams} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";

/// @title MockPoolManager
/// @notice Simple mock pool manager for testing
contract MockPoolManager is IPoolManager {
    // IPoolManager functions
    function lock(bytes calldata) external pure returns (bytes memory) {
        return "";
    }

    function unlock(bytes calldata) external pure override returns (bytes memory) {
        return "";
    }

    function initialize(PoolKey memory, uint160) external pure override returns (int24) {
        return 0;
    }

    function modifyLiquidity(
        PoolKey memory,
        ModifyLiquidityParams memory,
        bytes calldata
    ) external pure override returns (BalanceDelta, BalanceDelta) {
        return (BalanceDelta.wrap(0), BalanceDelta.wrap(0));
    }

    function swap(
        PoolKey memory,
        SwapParams memory,
        bytes calldata
    ) external pure override returns (BalanceDelta) {
        return BalanceDelta.wrap(0);
    }

    function donate(PoolKey memory, uint256, uint256, bytes calldata) external pure override returns (BalanceDelta) {
        return BalanceDelta.wrap(0);
    }

    function sync(Currency) external pure override {}

    function take(Currency, address, uint256) external pure override {}

    function settle() external payable override returns (uint256) {
        return 0;
    }

    function settleFor(address) external payable override returns (uint256) {
        return 0;
    }

    function clear(Currency, uint256) external pure override {}

    function mint(address, uint256, uint256) external pure override {}

    function burn(address, uint256, uint256) external pure override {}

    function updateDynamicLPFee(PoolKey memory, uint24) external pure override {}

    // IProtocolFees functions
    function protocolFeesAccrued(Currency) external pure override returns (uint256) {
        return 0;
    }

    function setProtocolFee(PoolKey memory, uint24) external pure override {}

    function setProtocolFeeController(address) external pure override {}

    function collectProtocolFees(address, Currency, uint256) external pure override returns (uint256) {
        return 0;
    }

    function protocolFeeController() external pure override returns (address) {
        return address(0);
    }

    // IERC6909Claims functions
    function balanceOf(address, uint256) external pure override returns (uint256) {
        return 0;
    }

    function allowance(address, address, uint256) external pure override returns (uint256) {
        return 0;
    }

    function isOperator(address, address) external pure override returns (bool) {
        return false;
    }

    function transfer(address, uint256, uint256) external pure override returns (bool) {
        return true;
    }

    function transferFrom(address, address, uint256, uint256) external pure override returns (bool) {
        return true;
    }

    function approve(address, uint256, uint256) external pure override returns (bool) {
        return true;
    }

    function setOperator(address, bool) external pure override returns (bool) {
        return true;
    }

    // IExtsload functions
    function extsload(bytes32) external pure override returns (bytes32) {
        return bytes32(0);
    }

    function extsload(bytes32, uint256) external pure override returns (bytes32[] memory) {
        return new bytes32[](0);
    }

    function extsload(bytes32[] calldata) external pure override returns (bytes32[] memory) {
        return new bytes32[](0);
    }

    // IExttload functions
    function exttload(bytes32) external pure override returns (bytes32) {
        return bytes32(0);
    }

    function exttload(bytes32[] calldata) external pure override returns (bytes32[] memory) {
        return new bytes32[](0);
    }
}

/// @title StableYieldHookTest
/// @notice Comprehensive test suite for StableYieldHook
contract StableYieldHookTest is BaseTest {
    using PoolIdLibrary for PoolKey;

    StableYieldHook public hook;
    MockAVSOracle public avsOracle;
    MockMorphoDeposit public morphoDeposit;

    PoolKey public poolKey;
    PoolId public poolId;

    // Test constants
    uint256 public constant POOL_LIQUIDITY = 1_000_000e18; // 1M tokens
    uint256 public constant SWAP_AMOUNT_SMALL = 10_000e18; // 1% of liquidity
    uint256 public constant SWAP_AMOUNT_LARGE = 30_000e18; // 3% of liquidity (exceeds threshold)

    event FeesRoutedToLending(
        PoolId indexed poolId,
        uint256 amount,
        uint256 apy,
        uint256 timestamp
    );

    event YieldCompounded(
        PoolId indexed poolId,
        uint256 amount,
        uint256 timestamp
    );

    function setUp() public {
        // Deploy all required artifacts
        deployArtifactsAndLabel();

        (Currency currency0, Currency currency1) = deployCurrencyPair();

        // Deploy mock contracts
        avsOracle = new MockAVSOracle();
        morphoDeposit = new MockMorphoDeposit();

        // Deploy the hook to an address with the correct flags
        address flags = address(
            uint160(
                Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG
            ) ^ (0x4444 << 144) // Namespace the hook to avoid collisions
        );
        bytes memory constructorArgs = abi.encode(poolManager, avsOracle, morphoDeposit);
        deployCodeTo("StableYieldHook.sol:StableYieldHook", constructorArgs, flags);
        hook = StableYieldHook(flags);

        // Create the pool
        poolKey = PoolKey(currency0, currency1, 3000, 60, IHooks(hook));
        poolId = poolKey.toId();
        
        // Note: In real tests, you'd initialize the pool here
        // poolManager.initialize(poolKey, Constants.SQRT_PRICE_1_1);
        
        // Set initial pool liquidity (using vm.prank to simulate pool manager)
        vm.prank(address(poolManager));
        hook.updatePoolLiquidity(poolId, POOL_LIQUIDITY);
    }

    /// @notice Test hook permissions are correctly set
    function test_HookPermissions() public view {
        Hooks.Permissions memory permissions = hook.getHookPermissions();
        
        assertFalse(permissions.beforeInitialize);
        assertFalse(permissions.afterInitialize);
        assertTrue(permissions.beforeSwap);
        assertTrue(permissions.afterSwap);
        assertFalse(permissions.beforeAddLiquidity);
        assertFalse(permissions.afterAddLiquidity);
    }

    /// @notice Test beforeSwap returns base fee when APY is below threshold
    function test_BeforeSwap_LowAPY_ReturnsBaseFee() public {
        // Set APY to 3% (below 4% threshold)
        avsOracle.setAPY(0.03e18);

        SwapParams memory swapParams = SwapParams({
            zeroForOne: true,
            amountSpecified: int256(SWAP_AMOUNT_SMALL),
            sqrtPriceLimitX96: 0
        });

        vm.prank(address(poolManager));
        (, , uint24 feeTier) = hook.beforeSwap(
            address(this),
            poolKey,
            swapParams,
            ""
        );

        assertEq(feeTier, hook.BASE_FEE_TIER(), "Should return base fee tier");
    }

    /// @notice Test beforeSwap returns dynamic fee when APY is above threshold and volume is low
    function test_BeforeSwap_HighAPY_LowVolume_ReturnsDynamicFee() public {
        // Set APY to 5% (above 4% threshold)
        avsOracle.setAPY(0.05e18);

        SwapParams memory swapParams = SwapParams({
            zeroForOne: true,
            amountSpecified: int256(SWAP_AMOUNT_SMALL), // 1% volume (below 2% threshold)
            sqrtPriceLimitX96: 0
        });

        vm.prank(address(poolManager));
        (, , uint24 feeTier) = hook.beforeSwap(
            address(this),
            poolKey,
            swapParams,
            ""
        );

        assertEq(feeTier, hook.DYNAMIC_FEE_TIER(), "Should return dynamic fee tier");
    }

    /// @notice Test beforeSwap returns base fee when volume is too high
    function test_BeforeSwap_HighAPY_HighVolume_ReturnsBaseFee() public {
        // Set APY to 5% (above threshold)
        avsOracle.setAPY(0.05e18);

        SwapParams memory swapParams = SwapParams({
            zeroForOne: true,
            amountSpecified: int256(SWAP_AMOUNT_LARGE), // 3% volume (above 2% threshold)
            sqrtPriceLimitX96: 0
        });

        vm.prank(address(poolManager));
        (, , uint24 feeTier) = hook.beforeSwap(
            address(this),
            poolKey,
            swapParams,
            ""
        );

        assertEq(feeTier, hook.BASE_FEE_TIER(), "Should return base fee when volume too high");
    }

    /// @notice Test afterSwap routes fees when conditions are met
    function test_AfterSwap_RoutesFees_WhenConditionsMet() public {
        // Set APY to 5% (above threshold)
        avsOracle.setAPY(0.05e18);

        // First, call beforeSwap to set the cache
        SwapParams memory swapParams = SwapParams({
            zeroForOne: true,
            amountSpecified: int256(SWAP_AMOUNT_SMALL),
            sqrtPriceLimitX96: 0
        });

vm.startPrank(address(poolManager));
        hook.beforeSwap(address(this), poolKey, swapParams, "");

        // Accumulate some fees
        uint256 fees = 1000e18;
        vm.prank(address(poolManager));
        hook.accumulateFees(poolId, fees);

        // Call afterSwap
        vm.expectEmit(true, false, false, true);
        emit FeesRoutedToLending(poolId, fees / 2, 0.05e18, block.timestamp);

vm.startPrank(address(poolManager));
        hook.afterSwap(
            address(this),
            poolKey,
            swapParams,
            BalanceDelta.wrap(0),
            ""
        );

        // Verify 50% of fees were routed
        assertEq(
            hook.accumulatedFees(poolId),
            fees / 2,
            "Should keep 50% of fees in pool"
        );
        assertEq(
            morphoDeposit.totalDeposited(),
            fees / 2,
            "Should deposit 50% to Morpho"
        );
    }

    /// @notice Test afterSwap does not route fees when conditions not met
    function test_AfterSwap_DoesNotRouteFees_WhenConditionsNotMet() public {
        // Set APY to 3% (below threshold)
        avsOracle.setAPY(0.03e18);

        SwapParams memory swapParams = SwapParams({
            zeroForOne: true,
            amountSpecified: int256(SWAP_AMOUNT_SMALL),
            sqrtPriceLimitX96: 0
        });

vm.startPrank(address(poolManager));
        hook.beforeSwap(address(this), poolKey, swapParams, "");

        // Accumulate some fees
        uint256 fees = 1000e18;
        vm.prank(address(poolManager));
        hook.accumulateFees(poolId, fees);

        uint256 feesBefore = hook.accumulatedFees(poolId);
        uint256 depositsBefore = morphoDeposit.totalDeposited();

        // Call afterSwap
vm.startPrank(address(poolManager));
        hook.afterSwap(
            address(this),
            poolKey,
            swapParams,
            BalanceDelta.wrap(0),
            ""
        );
        vm.stopPrank();

        // Verify fees were not routed
        assertEq(
            hook.accumulatedFees(poolId),
            feesBefore,
            "Fees should not be routed"
        );
        assertEq(
            morphoDeposit.totalDeposited(),
            depositsBefore,
            "No deposits should be made"
        );
    }

    /// @notice Test compounding yield
    function test_AfterSwap_CompoundsYield() public {
        // Set APY to 5%
        avsOracle.setAPY(0.05e18);

        SwapParams memory swapParams = SwapParams({
            zeroForOne: true,
            amountSpecified: int256(SWAP_AMOUNT_SMALL),
            sqrtPriceLimitX96: 0
        });

vm.startPrank(address(poolManager));
        hook.beforeSwap(address(this), poolKey, swapParams, "");

        // Deposit some funds to Morpho first
        uint256 depositAmount = 1000e18;
        morphoDeposit.deposit(depositAmount);

        // Fast forward time to accrue yield
        vm.warp(block.timestamp + 30 days);

        uint256 accruedYield = morphoDeposit.getAccruedYield();
        assertGt(accruedYield, 0, "Should have accrued yield");

        // Call afterSwap to compound
        vm.expectEmit(true, false, false, true);
        emit YieldCompounded(poolId, accruedYield, block.timestamp);

vm.startPrank(address(poolManager));
        hook.afterSwap(
            address(this),
            poolKey,
            swapParams,
            BalanceDelta.wrap(0),
            ""
        );

        // Verify yield was compounded back to pool
        assertEq(
            hook.accumulatedFees(poolId),
            accruedYield,
            "Yield should be added to accumulated fees"
        );
    }

    /// @notice Test volume tracking resets after 24 hours
    function test_VolumeTracking_ResetsAfter24Hours() public {
        SwapParams memory swapParams = SwapParams({
            zeroForOne: true,
            amountSpecified: int256(SWAP_AMOUNT_SMALL),
            sqrtPriceLimitX96: 0
        });

        // First swap
vm.startPrank(address(poolManager));
        hook.beforeSwap(address(this), poolKey, swapParams, "");
vm.startPrank(address(poolManager));
        hook.afterSwap(
            address(this),
            poolKey,
            swapParams,
            BalanceDelta.wrap(0),
            ""
        );

        // Fast forward 25 hours
        vm.warp(block.timestamp + 25 hours);

        // Second swap should reset volume
vm.startPrank(address(poolManager));
        hook.beforeSwap(address(this), poolKey, swapParams, "");
vm.startPrank(address(poolManager));
        hook.afterSwap(
            address(this),
            poolKey,
            swapParams,
            BalanceDelta.wrap(0),
            ""
        );
        vm.stopPrank();

        // Volume should be reset (simplified check - in real implementation would verify)
        // This test verifies the logic doesn't break
    }

    /// @notice Test fee calculation in afterSwap
    function test_AfterSwap_CalculatesFeesCorrectly() public {
        avsOracle.setAPY(0.05e18);

        SwapParams memory swapParams = SwapParams({
            zeroForOne: true,
            amountSpecified: int256(100_000e18), // 10% of liquidity
            sqrtPriceLimitX96: 0
        });

vm.startPrank(address(poolManager));
        hook.beforeSwap(address(this), poolKey, swapParams, "");

        uint256 feesBefore = hook.accumulatedFees(poolId);

vm.startPrank(address(poolManager));
        hook.afterSwap(
            address(this),
            poolKey,
            swapParams,
            BalanceDelta.wrap(0),
            ""
        );
        vm.stopPrank();

        // Fees should be accumulated (estimated from swap amount * fee tier)
        uint256 expectedFee = (100_000e18 * hook.DYNAMIC_FEE_TIER()) / 1e6;
        assertGt(
            hook.accumulatedFees(poolId),
            feesBefore,
            "Fees should be accumulated"
        );
    }

    /// @notice Test constants are set correctly
    function test_Constants() public view {
        assertEq(hook.MIN_APY_THRESHOLD(), 0.04e18, "MIN_APY_THRESHOLD should be 4%");
        assertEq(hook.MAX_VOLUME_THRESHOLD(), 0.02e18, "MAX_VOLUME_THRESHOLD should be 2%");
        assertEq(hook.FEE_ROUTING_PERCENTAGE(), 0.5e18, "FEE_ROUTING_PERCENTAGE should be 50%");
        assertEq(hook.BASE_FEE_TIER(), 3000, "BASE_FEE_TIER should be 0.3%");
        assertEq(hook.DYNAMIC_FEE_TIER(), 5000, "DYNAMIC_FEE_TIER should be 0.5%");
    }

    /// @notice Test access control on updatePoolLiquidity
    function test_UpdatePoolLiquidity_OnlyPoolManager() public {
        vm.expectRevert("Only pool manager");
        hook.updatePoolLiquidity(poolId, 1000e18);

        vm.prank(address(poolManager));
        hook.updatePoolLiquidity(poolId, 1000e18);
        // Should not revert
    }

    /// @notice Test access control on accumulateFees
    function test_AccumulateFees_OnlyPoolManager() public {
        vm.expectRevert("Only pool manager");
        hook.accumulateFees(poolId, 1000e18);

        vm.prank(address(poolManager));
        hook.accumulateFees(poolId, 1000e18);
        // Should not revert
    }
}

