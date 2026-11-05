// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Future module interface only. Strategies and strategy yield are NOT live in the MVP.
interface IStrategyManager {
    /// @notice Future allocation of asset base units into a strategy.
    function allocate(address strategy, uint256 assets) external;
    /// @notice Future recovery of asset base units from a strategy.
    function deallocate(address strategy, uint256 assets) external returns (uint256 recovered);
    /// @notice Future total managed assets query; no implementation is provided.
    function managedAssets(address asset) external view returns (uint256);
}
