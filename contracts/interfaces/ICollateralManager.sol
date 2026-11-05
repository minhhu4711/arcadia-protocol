// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Future module interface only. Collateralized borrowing is NOT live in the MVP.
interface ICollateralManager {
    /// @notice Future collateral deposit in token base units; no implementation is provided.
    function depositCollateral(address token, uint256 amount) external;
    /// @notice Future collateral withdrawal subject to solvency checks.
    function withdrawCollateral(address token, uint256 amount) external;
    /// @notice Future collateral-backed borrowing; unavailable in the MVP pools.
    function borrow(address market, uint256 amount) external;
    /// @notice Future debt repayment; unavailable in the MVP pools.
    function repay(address market, uint256 amount) external;
    /// @notice Future WAD health factor for an account.
    function healthFactor(address account) external view returns (uint256);
}
