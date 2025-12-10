// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../interfaces/IMockAVSOracle.sol";

/// @title MockAVSOracle
/// @notice Mock implementation of AVS oracle for PoC
/// @dev Uses simple storage variable to store APY
contract MockAVSOracle is IMockAVSOracle {
    /// @notice Current APY stored in storage (1e18 = 100%)
    uint256 private currentAPY;

    /// @notice Default APY (5% = 0.05e18) for testing
    constructor() {
        currentAPY = 0.05e18; // 5% default
    }

    /// @inheritdoc IMockAVSOracle
    function getAPY() external view override returns (uint256) {
        return currentAPY;
    }

    /// @inheritdoc IMockAVSOracle
    function setAPY(uint256 apy) external override {
        currentAPY = apy;
    }
}

