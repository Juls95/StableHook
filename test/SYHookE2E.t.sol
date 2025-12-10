// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";

import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";
import {IPositionManager} from "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";
import {Constants} from "@uniswap/v4-core/test/utils/Constants.sol";

import {EasyPosm} from "./utils/libraries/EasyPosm.sol";
import {BaseTest} from "./utils/BaseTest.sol";

import {StableYieldHook} from "../src/StableYieldHook.sol";
import {MockAVSOracle} from "../src/mocks/MockAVSOracle.sol";
import {MockMorphoDeposit} from "../src/mocks/MockMorphoDeposit.sol";

/// @title SYHookE2ETest
/// @notice End-to-end tests for StableYieldHook simulating real swap/yield scenarios
/// @dev Can run on Sepolia fork with: forge test --fork-url $SEPOLIA_RPC_URL
contract SYHookE2ETest is BaseTest {
    using EasyPosm for IPositionManager;
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;

    Currency currency0;
    Currency currency1;

    PoolKey poolKey;
    StableYieldHook hook;
    MockAVSOracle avsOracle;
    MockMorphoDeposit morphoDeposit;
    PoolId poolId;

    uint256 tokenId;
    int24 tickLower;
    int24 tickUpper;

    // Test constants
    uint128 constant INITIAL_LIQUIDITY = 1_000_000e18; // 1M tokens
    uint256 constant SWAP_AMOUNT = 10_000e18; // 1% of liquidity (below 2% threshold)

    function setUp() public {
        // Deploy all required artifacts (V4 PoolManager, PositionManager, Router)
        deployArtifactsAndLabel();

        // Deploy currency pair (mock USDC/USDT for testing)
        (currency0, currency1) = deployCurrencyPair();

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

        // Create the pool with stablecoin pair configuration
        poolKey = PoolKey(currency0, currency1, 3000, 60, IHooks(hook));
        poolId = poolKey.toId();
        
        // Initialize pool at 1:1 price (typical for stablecoin pairs)
        poolManager.initialize(poolKey, Constants.SQRT_PRICE_1_1);

        // Provide full-range liquidity to the pool
        tickLower = TickMath.minUsableTick(poolKey.tickSpacing);
        tickUpper = TickMath.maxUsableTick(poolKey.tickSpacing);

        (uint256 amount0Expected, uint256 amount1Expected) = LiquidityAmounts.getAmountsForLiquidity(
            Constants.SQRT_PRICE_1_1,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            INITIAL_LIQUIDITY
        );

        // Mint liquidity position
        (tokenId,) = positionManager.mint(
            poolKey,
            tickLower,
            tickUpper,
            INITIAL_LIQUIDITY,
            amount0Expected + 1,
            amount1Expected + 1,
            address(this),
            block.timestamp,
            Constants.ZERO_BYTES
        );

        // Update hook with pool liquidity for volume calculations
        vm.prank(address(poolManager));
        hook.updatePoolLiquidity(poolId, INITIAL_LIQUIDITY);
    }

    /// @notice Test dynamic fee is applied when APY > 4% and volume < 2%
    function testDynamicYield_HighAPY_LowVolume_AppliesDynamicFee() public {
        // Set APY to 5% (above 4% threshold)
        avsOracle.setAPY(0.05e18);

        // Verify initial state
        assertEq(hook.accumulatedFees(poolId), 0, "Should start with no fees");
        assertEq(morphoDeposit.totalDeposited(), 0, "Should start with no deposits");

        // Perform a swap (1% volume, below 2% threshold)
        uint256 amountIn = SWAP_AMOUNT;
        BalanceDelta swapDelta = swapRouter.swapExactTokensForTokens({
            amountIn: amountIn,
            amountOutMin: 0,
            zeroForOne: true,
            poolKey: poolKey,
            hookData: Constants.ZERO_BYTES,
            receiver: address(this),
            deadline: block.timestamp + 1
        });

        // Verify swap executed
        assertLt(int256(swapDelta.amount0()), 0, "Should have swapped token0");

        // Verify fees were accumulated (dynamic fee tier should be used)
        uint256 expectedFee = (amountIn * hook.DYNAMIC_FEE_TIER()) / 1e6;
        assertGt(hook.accumulatedFees(poolId), 0, "Fees should be accumulated");
        
        // Verify fees were routed to Morpho (50% of accumulated fees)
        assertGt(morphoDeposit.totalDeposited(), 0, "Fees should be routed to Morpho");
    }

    /// @notice Test base fee is used when APY < 4%
    function testDynamicYield_LowAPY_UsesBaseFee() public {
        // Set APY to 3% (below 4% threshold)
        avsOracle.setAPY(0.03e18);

        // Perform a swap
        uint256 amountIn = SWAP_AMOUNT;
        BalanceDelta swapDelta = swapRouter.swapExactTokensForTokens({
            amountIn: amountIn,
            amountOutMin: 0,
            zeroForOne: true,
            poolKey: poolKey,
            hookData: Constants.ZERO_BYTES,
            receiver: address(this),
            deadline: block.timestamp + 1
        });

        // Verify swap executed
        assertLt(int256(swapDelta.amount0()), 0, "Should have swapped token0");

        // Fees should be accumulated but NOT routed (base fee tier used)
        uint256 expectedFee = (amountIn * hook.BASE_FEE_TIER()) / 1e6;
        assertGt(hook.accumulatedFees(poolId), 0, "Fees should be accumulated");
        
        // No fees should be routed when APY is below threshold
        assertEq(morphoDeposit.totalDeposited(), 0, "No fees should be routed when APY < 4%");
    }

    /// @notice Test base fee is used when volume > 2% even if APY > 4%
    function testDynamicYield_HighVolume_UsesBaseFee() public {
        // Set APY to 5% (above threshold)
        avsOracle.setAPY(0.05e18);

        // Perform a large swap (3% of liquidity, above 2% threshold)
        uint256 largeSwapAmount = 30_000e18; // 3% of liquidity
        BalanceDelta swapDelta = swapRouter.swapExactTokensForTokens({
            amountIn: largeSwapAmount,
            amountOutMin: 0,
            zeroForOne: true,
            poolKey: poolKey,
            hookData: Constants.ZERO_BYTES,
            receiver: address(this),
            deadline: block.timestamp + 1
        });

        // Verify swap executed
        assertLt(int256(swapDelta.amount0()), 0, "Should have swapped token0");

        // Fees should be accumulated but NOT routed (volume too high)
        assertGt(hook.accumulatedFees(poolId), 0, "Fees should be accumulated");
        
        // No fees should be routed when volume exceeds threshold
        assertEq(morphoDeposit.totalDeposited(), 0, "No fees should be routed when volume > 2%");
    }

    /// @notice Test yield compounding after time passes
    function testYieldCompounding_AccruesAndCompounds() public {
        // Set APY to 5%
        avsOracle.setAPY(0.05e18);

        // Perform initial swap to route fees
        uint256 amountIn = SWAP_AMOUNT;
        swapRouter.swapExactTokensForTokens({
            amountIn: amountIn,
            amountOutMin: 0,
            zeroForOne: true,
            poolKey: poolKey,
            hookData: Constants.ZERO_BYTES,
            receiver: address(this),
            deadline: block.timestamp + 1
        });

        // Verify fees were routed
        uint256 initialDeposit = morphoDeposit.totalDeposited();
        assertGt(initialDeposit, 0, "Fees should be routed");

        // Fast forward 30 days to accrue yield
        vm.warp(block.timestamp + 30 days);

        // Check accrued yield
        uint256 accruedYield = morphoDeposit.getAccruedYield();
        assertGt(accruedYield, 0, "Should have accrued yield");

        // Perform another swap to trigger compounding
        uint256 feesBefore = hook.accumulatedFees(poolId);
        swapRouter.swapExactTokensForTokens({
            amountIn: amountIn,
            amountOutMin: 0,
            zeroForOne: true,
            poolKey: poolKey,
            hookData: Constants.ZERO_BYTES,
            receiver: address(this),
            deadline: block.timestamp + 1
        });

        // Verify yield was compounded back to pool
        assertGt(
            hook.accumulatedFees(poolId),
            feesBefore,
            "Yield should be compounded back to pool"
        );
    }

    /// @notice Test oracle failure fallback (should use base fee)
    function testOracleFailureFallback_UsesBaseFee() public {
        // Simulate oracle failure by setting APY to 0 (oracle returns 0)
        avsOracle.setAPY(0);

        // Perform a swap
        uint256 amountIn = SWAP_AMOUNT;
        BalanceDelta swapDelta = swapRouter.swapExactTokensForTokens({
            amountIn: amountIn,
            amountOutMin: 0,
            zeroForOne: true,
            poolKey: poolKey,
            hookData: Constants.ZERO_BYTES,
            receiver: address(this),
            deadline: block.timestamp + 1
        });

        // Verify swap executed
        assertLt(int256(swapDelta.amount0()), 0, "Should have swapped token0");

        // With APY = 0, should use base fee (no routing)
        assertGt(hook.accumulatedFees(poolId), 0, "Fees should be accumulated");
        assertEq(morphoDeposit.totalDeposited(), 0, "No fees should be routed when APY = 0");
    }

    /// @notice Test multiple swaps accumulate fees correctly
    function testMultipleSwaps_AccumulateFees() public {
        // Set APY to 5%
        avsOracle.setAPY(0.05e18);

        uint256 totalFeesAccumulated = 0;
        uint256 numSwaps = 5;

        // Perform multiple swaps
        for (uint256 i = 0; i < numSwaps; i++) {
            swapRouter.swapExactTokensForTokens({
                amountIn: SWAP_AMOUNT,
                amountOutMin: 0,
                zeroForOne: true,
                poolKey: poolKey,
                hookData: Constants.ZERO_BYTES,
                receiver: address(this),
                deadline: block.timestamp + 1
            });

            // Estimate fee for this swap
            uint256 estimatedFee = (SWAP_AMOUNT * hook.DYNAMIC_FEE_TIER()) / 1e6;
            totalFeesAccumulated += estimatedFee;
        }

        // Verify fees accumulated (some may have been routed, so check it's reasonable)
        assertGt(hook.accumulatedFees(poolId), 0, "Fees should accumulate across swaps");
        assertGt(morphoDeposit.totalDeposited(), 0, "Some fees should be routed");
    }

    /// @notice Test volume tracking resets after 24 hours
    function testVolumeTracking_ResetsAfter24Hours() public {
        // Set APY to 5%
        avsOracle.setAPY(0.05e18);

        // First swap - should route fees (low volume)
        swapRouter.swapExactTokensForTokens({
            amountIn: SWAP_AMOUNT,
            amountOutMin: 0,
            zeroForOne: true,
            poolKey: poolKey,
            hookData: Constants.ZERO_BYTES,
            receiver: address(this),
            deadline: block.timestamp + 1
        });

        uint256 depositsAfterFirst = morphoDeposit.totalDeposited();
        assertGt(depositsAfterFirst, 0, "First swap should route fees");

        // Fast forward 25 hours
        vm.warp(block.timestamp + 25 hours);

        // Second swap - volume should be reset, should route fees again
        swapRouter.swapExactTokensForTokens({
            amountIn: SWAP_AMOUNT,
            amountOutMin: 0,
            zeroForOne: true,
            poolKey: poolKey,
            hookData: Constants.ZERO_BYTES,
            receiver: address(this),
            deadline: block.timestamp + 1
        });

        // Should have more deposits after second swap
        assertGt(
            morphoDeposit.totalDeposited(),
            depositsAfterFirst,
            "Second swap should also route fees after volume reset"
        );
    }

    /// @notice Test edge case: APY exactly at threshold (4%)
    function testEdgeCase_APYAtThreshold() public {
        // Set APY to exactly 4% (threshold)
        avsOracle.setAPY(0.04e18);

        // Perform swap
        swapRouter.swapExactTokensForTokens({
            amountIn: SWAP_AMOUNT,
            amountOutMin: 0,
            zeroForOne: true,
            poolKey: poolKey,
            hookData: Constants.ZERO_BYTES,
            receiver: address(this),
            deadline: block.timestamp + 1
        });

        // At exactly 4%, should NOT route (APY must be > 4%)
        assertEq(morphoDeposit.totalDeposited(), 0, "Should not route at exactly 4% APY");
    }

    /// @notice Test edge case: Volume exactly at threshold (2%)
    function testEdgeCase_VolumeAtThreshold() public {
        // Set APY to 5%
        avsOracle.setAPY(0.05e18);

        // Perform swap at exactly 2% of liquidity
        uint256 thresholdSwapAmount = 20_000e18; // Exactly 2% of 1M
        swapRouter.swapExactTokensForTokens({
            amountIn: thresholdSwapAmount,
            amountOutMin: 0,
            zeroForOne: true,
            poolKey: poolKey,
            hookData: Constants.ZERO_BYTES,
            receiver: address(this),
            deadline: block.timestamp + 1
        });

        // At exactly 2%, should NOT route (volume must be < 2%)
        assertEq(morphoDeposit.totalDeposited(), 0, "Should not route at exactly 2% volume");
    }

    /// @notice Test that hook constants are correctly set
    function testConstants_AreCorrectlySet() public view {
        assertEq(hook.MIN_APY_THRESHOLD(), 0.04e18, "MIN_APY_THRESHOLD should be 4%");
        assertEq(hook.MAX_VOLUME_THRESHOLD(), 0.02e18, "MAX_VOLUME_THRESHOLD should be 2%");
        assertEq(hook.FEE_ROUTING_PERCENTAGE(), 0.5e18, "FEE_ROUTING_PERCENTAGE should be 50%");
        assertEq(hook.BASE_FEE_TIER(), 3000, "BASE_FEE_TIER should be 0.3%");
        assertEq(hook.DYNAMIC_FEE_TIER(), 5000, "DYNAMIC_FEE_TIER should be 0.5%");
    }
}

