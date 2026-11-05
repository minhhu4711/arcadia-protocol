// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Annual WAD rates; interest uses linear elapsed-time accrual over 365 days.
interface IInterestRateModel {
    /// @notice Utilization in WAD, using accounted available liquidity and outstanding debt.
    function utilization(uint256 cash, uint256 borrows) external pure returns (uint256);
    /// @notice Annual borrow rate in WAD for utilization in [0, 1e18].
    function getBorrowRate(uint256 utilizationWad) external view returns (uint256);
    /// @notice Annual lender rate in WAD after the WAD reserve factor.
    function getSupplyRate(uint256 utilizationWad, uint256 reserveFactorWad) external view returns (uint256);
}
