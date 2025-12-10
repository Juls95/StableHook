// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title IMockAVSOracle
/// @notice Mock interface for EigenLayer AVS oracle
interface IMockAVSOracle {
    /// @notice Get current APY from lending protocols
    /// @return apy The APY as a fixed-point number (1e18 = 100%)
    function getAPY() external view returns (uint256 apy);
    
    /// @notice Set APY (for testing/PoC)
    /// @param apy The APY to set (1e18 = 100%)
    function setAPY(uint256 apy) external;
}

