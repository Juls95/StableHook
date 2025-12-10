// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BaseHook} from "@openzeppelin/uniswap-hooks/src/base/BaseHook.sol";

import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager, SwapParams, ModifyLiquidityParams} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {IMockAVSOracle} from "./interfaces/IMockAVSOracle.sol";
import {IMockMorphoDeposit} from "./interfaces/IMockMorphoDeposit.sol";

/// @title StableYieldHook
/// @notice Uniswap V4 hook that optimizes yield for stablecoin pairs by routing fees to lending protocols
contract StableYieldHook is BaseHook {
    using PoolIdLibrary for PoolKey;
    using BeforeSwapDeltaLibrary for BeforeSwapDelta;

    /// @notice Minimum APY threshold (4% = 0.04e18)
    uint256 public constant MIN_APY_THRESHOLD = 0.04e18;
    
    /// @notice Maximum volume threshold (2% = 0.02e18)
    uint256 public constant MAX_VOLUME_THRESHOLD = 0.02e18;
    
    /// @notice Fee routing percentage when conditions are met (50% = 0.5e18)
    uint256 public constant FEE_ROUTING_PERCENTAGE = 0.5e18;
    
    /// @notice Base fee tier (0.3% = 3000)
    uint24 public constant BASE_FEE_TIER = 3000;
    
    /// @notice Dynamic fee tier when yield routing is active (0.5% = 5000)
    uint24 public constant DYNAMIC_FEE_TIER = 5000;

    /// @notice Mock AVS Oracle contract
    IMockAVSOracle public immutable avsOracle;
    
    /// @notice Mock Morpho deposit contract
    IMockMorphoDeposit public immutable morphoDeposit;

    /// @notice Track accumulated fees per pool
    mapping(PoolId => uint256) public accumulatedFees;
    
    /// @notice Track last swap timestamp per pool for volume calculation
    mapping(PoolId => uint256) public lastSwapTimestamp;
    
    /// @notice Track swap volume per pool (24h window)
    mapping(PoolId => uint256) public swapVolume;

    /// @notice Track total liquidity per pool
    mapping(PoolId => uint256) public poolLiquidity;
    
    /// @notice Track routing decision per pool (for afterSwap)
    mapping(PoolId => bool) private shouldRouteFeesCache;

    /// @notice Emitted when fees are routed to lending protocol
    event FeesRoutedToLending(
        PoolId indexed poolId,
        uint256 amount,
        uint256 apy,
        uint256 timestamp
    );

    /// @notice Emitted when yield is compounded back to pool
    event YieldCompounded(
        PoolId indexed poolId,
        uint256 amount,
        uint256 timestamp
    );

    constructor(
        IPoolManager _poolManager,
        IMockAVSOracle _avsOracle,
        IMockMorphoDeposit _morphoDeposit
    ) BaseHook(_poolManager) {
        avsOracle = _avsOracle;
        morphoDeposit = _morphoDeposit;
    }

    /// @notice Hook configuration - only enable beforeSwap and afterSwap
    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    /// @notice Called before each swap to check APY and route fees
    /// @param key The pool key
    /// @param swapParams Swap parameters
    /// @param hookData Additional hook data
    /// @return selector Function selector
    /// @return delta The before swap delta (fee adjustment)
    /// @return feeTier The fee tier to use for this swap
    function _beforeSwap(
        address,
        PoolKey calldata key,
        SwapParams calldata swapParams,
        bytes calldata hookData
    ) internal override returns (bytes4, BeforeSwapDelta, uint24) {
        PoolId poolId = key.toId();
        
        // Fetch APY from AVS oracle
        uint256 apy = avsOracle.getAPY();
        
        // Calculate current volume percentage
        uint256 currentVolume = _calculateVolume(poolId, swapParams.amountSpecified);
        
        // Determine if we should route fees to lending
        // Conditions: APY > 4% AND volume < 2%
        bool shouldRouteFees = apy > MIN_APY_THRESHOLD && currentVolume < MAX_VOLUME_THRESHOLD;
        
        // Cache the decision for afterSwap
        shouldRouteFeesCache[poolId] = shouldRouteFees;
        
        // Select fee tier based on conditions
        // Higher fee tier when yield routing is active
        uint24 feeTier = shouldRouteFees ? DYNAMIC_FEE_TIER : BASE_FEE_TIER;
        
        return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, feeTier);
    }

    /// @notice Called after each swap to compound yield and route fees
    /// @param key The pool key
    /// @param swapParams Swap parameters
    /// @param delta The balance delta from the swap
    /// @param hookData Additional hook data
    /// @return selector Function selector
    /// @return hookDelta Additional delta to apply
    function _afterSwap(
        address,
        PoolKey calldata key,
        SwapParams calldata swapParams,
        BalanceDelta delta,
        bytes calldata hookData
    ) internal override returns (bytes4, int128) {
        PoolId poolId = key.toId();
        
        // Update volume tracking
        _updateVolume(poolId, swapParams.amountSpecified);
        
        // Estimate fees from swap (fees are collected by pool manager, but we estimate here)
        // Fee = swap amount * fee tier / 1e6
        uint256 absSwapAmount = swapParams.amountSpecified < 0 
            ? uint256(-swapParams.amountSpecified) 
            : uint256(swapParams.amountSpecified);
        
        // Get the fee tier that was used (from cached decision)
        uint24 feeTier = shouldRouteFeesCache[poolId] ? DYNAMIC_FEE_TIER : BASE_FEE_TIER;
        uint256 estimatedFee = (absSwapAmount * feeTier) / 1e6;
        
        // Accumulate fees
        accumulatedFees[poolId] += estimatedFee;
        
        // Check if we should route fees (use cached decision from beforeSwap)
        bool shouldRouteFees = shouldRouteFeesCache[poolId];
        
        if (shouldRouteFees) {
            // Get accumulated fees for this pool
            uint256 feesToRoute = accumulatedFees[poolId];
            
            if (feesToRoute > 0) {
                // Route 50% of accumulated fees to Morpho
                uint256 routingAmount = (feesToRoute * FEE_ROUTING_PERCENTAGE) / 1e18;
                
                // Deposit to Morpho (mock)
                // Note: In production, this would transfer tokens and call deposit
                morphoDeposit.deposit(routingAmount);
                
                // Update accumulated fees (keep 50% in pool)
                accumulatedFees[poolId] = feesToRoute - routingAmount;
                
                uint256 apy = avsOracle.getAPY();
                emit FeesRoutedToLending(poolId, routingAmount, apy, block.timestamp);
            }
        }
        
        // Compound any accrued yield from previous deposits
        _compoundYield(poolId);
        
        // Clear cache
        shouldRouteFeesCache[poolId] = false;
        
        return (BaseHook.afterSwap.selector, 0);
    }

    /// @notice Compound yield from lending protocol back to pool
    /// @param poolId The pool ID
    function _compoundYield(PoolId poolId) internal {
        // Check for accrued yield in Morpho
        uint256 accruedYield = morphoDeposit.getAccruedYield();
        
        if (accruedYield > 0) {
            // Withdraw yield from Morpho
            morphoDeposit.withdrawYield(accruedYield);
            
            // In production, this yield would be distributed proportionally to LPs
            // For PoC, we track it in accumulatedFees to be distributed later
            accumulatedFees[poolId] += accruedYield;
            
            emit YieldCompounded(poolId, accruedYield, block.timestamp);
        }
    }

    /// @notice Calculate current volume percentage
    /// @param poolId The pool ID
    /// @param swapAmount The swap amount
    /// @return volume The volume as a percentage of liquidity
    function _calculateVolume(PoolId poolId, int256 swapAmount) internal view returns (uint256) {
        uint256 liquidity = poolLiquidity[poolId];
        if (liquidity == 0) return 0;
        
        uint256 absSwapAmount = swapAmount < 0 ? uint256(-swapAmount) : uint256(swapAmount);
        return (absSwapAmount * 1e18) / liquidity;
    }

    /// @notice Update volume tracking
    /// @param poolId The pool ID
    /// @param swapAmount The swap amount
    function _updateVolume(PoolId poolId, int256 swapAmount) internal {
        // Simplified volume tracking: reset after 24 hours
        if (block.timestamp - lastSwapTimestamp[poolId] > 1 days) {
            swapVolume[poolId] = 0;
        }
        
        uint256 absSwapAmount = swapAmount < 0 ? uint256(-swapAmount) : uint256(swapAmount);
        swapVolume[poolId] += absSwapAmount;
        lastSwapTimestamp[poolId] = block.timestamp;
    }

    /// @notice Update pool liquidity (called externally when liquidity changes)
    /// @param poolId The pool ID
    /// @param liquidity The new liquidity amount
    /// @dev In production, this would be called by the pool manager or tracked automatically
    function updatePoolLiquidity(PoolId poolId, uint256 liquidity) external {
        // Only pool manager can update liquidity
        require(msg.sender == address(poolManager), "Only pool manager");
        poolLiquidity[poolId] = liquidity;
    }

    /// @notice Accumulate fees (called by pool manager or hook logic)
    /// @param poolId The pool ID
    /// @param feeAmount The fee amount to accumulate
    /// @dev In production, this would be called automatically by the pool manager
    ///      For PoC, we expose it for testing
    function accumulateFees(PoolId poolId, uint256 feeAmount) external {
        // Only pool manager can accumulate fees
        require(msg.sender == address(poolManager), "Only pool manager");
        accumulatedFees[poolId] += feeAmount;
    }
}

