// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {StableYieldHook} from "../contracts/StableYieldHook.sol";
import {MockAVSOracle} from "../contracts/mocks/MockAVSOracle.sol";
import {MockMorphoDeposit} from "../contracts/mocks/MockMorphoDeposit.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";

/// @title MockPoolManager for integration tests
contract MockPoolManagerIntegration is IPoolManager {
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
        IPoolManager.ModifyLiquidityParams memory,
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

/// @title IntegrationTest
/// @notice Integration tests simulating full swap flow
contract IntegrationTest is Test {
    using PoolIdLibrary for PoolKey;

    StableYieldHook public hook;
    MockPoolManagerIntegration public poolManager;
    MockAVSOracle public avsOracle;
    MockMorphoDeposit public morphoDeposit;

    PoolKey public poolKey;
    PoolId public poolId;

    uint256 public constant POOL_LIQUIDITY = 10_000_000e18; // 10M tokens

    function setUp() public {
        poolManager = new MockPoolManagerIntegration();
        avsOracle = new MockAVSOracle();
        morphoDeposit = new MockMorphoDeposit();

        hook = new StableYieldHook(
            IPoolManager(address(poolManager)),
            avsOracle,
            morphoDeposit
        );

        poolKey = PoolKey({
            currency0: Currency.wrap(address(0x1)),
            currency1: Currency.wrap(address(0x2)),
            fee: 3000,
            tickSpacing: 60,
            hooks: StableYieldHook(address(hook))
        });

        poolId = poolKey.toId();

        vm.prank(address(poolManager));
        hook.updatePoolLiquidity(poolId, POOL_LIQUIDITY);
    }

    /// @notice Test complete flow: swap with high APY routes fees
    function test_CompleteFlow_HighAPY_RoutesFees() public {
        // Setup: High APY (5%)
        avsOracle.setAPY(0.05e18);

        // Simulate a swap
        SwapParams memory swapParams = SwapParams({
            zeroForOne: true,
            amountSpecified: int256(100_000e18), // 1% of liquidity
            sqrtPriceLimitX96: 0
        });

        // beforeSwap: Should return dynamic fee
        vm.prank(address(poolManager));
        (, , uint24 feeTier) = hook.beforeSwap(
            address(this),
            poolKey,
            swapParams,
            ""
        );
        assertEq(feeTier, hook.DYNAMIC_FEE_TIER());

        // Simulate fee accumulation (in real scenario, this happens in pool manager)
        uint256 estimatedFee = (100_000e18 * feeTier) / 1e6;
        vm.prank(address(poolManager));
        hook.accumulateFees(poolId, estimatedFee);

        // afterSwap: Should route fees
        vm.prank(address(poolManager));
vm.prank(address(poolManager));
        hook.afterSwap(
            address(this),
            poolKey,
            swapParams,
            BalanceDelta.wrap(0),
            ""
        );

        // Verify: 50% routed to Morpho
        assertEq(
            morphoDeposit.totalDeposited(),
            estimatedFee / 2,
            "50% should be routed"
        );
        assertEq(
            hook.accumulatedFees(poolId),
            estimatedFee / 2,
            "50% should remain"
        );
    }

    /// @notice Test complete flow: multiple swaps with compounding
    function test_CompleteFlow_MultipleSwaps_WithCompounding() public {
        avsOracle.setAPY(0.05e18);

        SwapParams memory swapParams = SwapParams({
            zeroForOne: true,
            amountSpecified: int256(100_000e18),
            sqrtPriceLimitX96: 0
        });

        // First swap
vm.prank(address(poolManager));
        hook.beforeSwap(address(this), poolKey, swapParams, "");
        uint256 fee1 = (100_000e18 * hook.DYNAMIC_FEE_TIER()) / 1e6;
        vm.prank(address(poolManager));
        hook.accumulateFees(poolId, fee1);
vm.prank(address(poolManager));
        hook.afterSwap(address(this), poolKey, swapParams, BalanceDelta.wrap(0), "");

        // Fast forward to accrue yield
        vm.warp(block.timestamp + 30 days);

        // Second swap - should compound yield
vm.prank(address(poolManager));
        hook.beforeSwap(address(this), poolKey, swapParams, "");
        uint256 fee2 = (100_000e18 * hook.DYNAMIC_FEE_TIER()) / 1e6;
        vm.prank(address(poolManager));
        hook.accumulateFees(poolId, fee2);
vm.prank(address(poolManager));
        hook.afterSwap(address(this), poolKey, swapParams, BalanceDelta.wrap(0), "");

        // Verify yield was compounded
        uint256 accruedYield = morphoDeposit.getAccruedYield();
        // After withdrawal, yield should be in accumulated fees
        assertGt(hook.accumulatedFees(poolId), fee1 / 2 + fee2 / 2, "Should include compounded yield");
    }

    /// @notice Test APY threshold edge case
    function test_APYThreshold_EdgeCase() public {
        // Exactly at threshold (4%)
        avsOracle.setAPY(0.04e18);

        SwapParams memory swapParams = SwapParams({
            zeroForOne: true,
            amountSpecified: int256(100_000e18),
            sqrtPriceLimitX96: 0
        });

        (, , uint24 feeTier) = hook.beforeSwap(
            address(this),
            poolKey,
            swapParams,
            ""
        );

        // Should use base fee (APY must be > 4%, not >=)
        assertEq(feeTier, hook.BASE_FEE_TIER(), "Should use base fee at threshold");

        // Just above threshold
        avsOracle.setAPY(0.0400001e18);
        (, , feeTier) = hook.beforeSwap(address(this), poolKey, swapParams, "");
        assertEq(feeTier, hook.DYNAMIC_FEE_TIER(), "Should use dynamic fee above threshold");
    }

    /// @notice Test volume threshold edge case
    function test_VolumeThreshold_EdgeCase() public {
        avsOracle.setAPY(0.05e18);

        // Exactly at volume threshold (2%)
        uint256 swapAmountAtThreshold = (POOL_LIQUIDITY * 2) / 100;

        SwapParams memory swapParams = SwapParams({
            zeroForOne: true,
            amountSpecified: int256(swapAmountAtThreshold),
            sqrtPriceLimitX96: 0
        });

        (, , uint24 feeTier) = hook.beforeSwap(
            address(this),
            poolKey,
            swapParams,
            ""
        );

        // Should use base fee (volume must be < 2%, not <=)
        assertEq(feeTier, hook.BASE_FEE_TIER(), "Should use base fee at volume threshold");
    }
}

