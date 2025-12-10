// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IMockMorphoDeposit
/// @notice Mock interface for Morpho Blue deposit
interface IMockMorphoDeposit {
    /// @notice Deposit funds to Morpho Blue
    /// @param amount The amount to deposit
    function deposit(uint256 amount) external;
    
    /// @notice Get accrued yield from deposits
    /// @return yield The accrued yield amount
    function getAccruedYield() external view returns (uint256 yield);
    
    /// @notice Withdraw yield
    /// @param amount The amount of yield to withdraw
    function withdrawYield(uint256 amount) external;
}

