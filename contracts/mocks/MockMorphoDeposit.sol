// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IMockMorphoDeposit.sol";

/// @title MockMorphoDeposit
/// @notice Mock implementation of Morpho Blue deposit for PoC
contract MockMorphoDeposit is IMockMorphoDeposit {
    /// @notice Total deposited amount
    uint256 public totalDeposited;
    
    /// @notice Accrued yield (simplified: linear accrual based on APY)
    uint256 public accruedYield;
    
    /// @notice APY for yield calculation (1e18 = 100%)
    uint256 public constant YIELD_APY = 0.06e18; // 6% APY
    
    /// @notice Last update timestamp
    uint256 public lastUpdateTimestamp;

    constructor() {
        lastUpdateTimestamp = block.timestamp;
    }

    /// @inheritdoc IMockMorphoDeposit
    function deposit(uint256 amount) external override {
        // Update accrued yield before new deposit
        _updateYield();
        
        totalDeposited += amount;
    }

    /// @inheritdoc IMockMorphoDeposit
    function getAccruedYield() external view override returns (uint256) {
        // Calculate yield based on time elapsed and deposited amount
        uint256 timeElapsed = block.timestamp - lastUpdateTimestamp;
        uint256 annualYield = (totalDeposited * YIELD_APY) / 1e18;
        uint256 yieldForPeriod = (annualYield * timeElapsed) / 365 days;
        
        return accruedYield + yieldForPeriod;
    }

    /// @inheritdoc IMockMorphoDeposit
    function withdrawYield(uint256 amount) external override {
        _updateYield();
        
        require(accruedYield >= amount, "Insufficient yield");
        accruedYield -= amount;
    }

    /// @notice Update accrued yield based on time elapsed
    function _updateYield() internal {
        uint256 currentYield = this.getAccruedYield();
        accruedYield = currentYield;
        lastUpdateTimestamp = block.timestamp;
    }
}

