// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice MVP supply market; borrowing and repayment are NOT live external operations.
interface ILendingPool {
    struct MarketState {
        uint256 supplied;
        uint256 borrowed;
        uint256 reserves;
        uint256 shares;
        uint256 liquidity;
        uint256 utilizationWad;
        uint256 borrowRateWad;
        uint256 supplyRateWad;
        uint256 lastAccrual;
    }
    /// @notice Supply underlying base units for the caller.
    function supply(uint256 amount) external returns (uint256 shares);
    /// @notice Supply underlying base units for another account.
    function supplyFor(address onBehalfOf, uint256 amount) external returns (uint256 shares);
    /// @notice Withdraw underlying, rounding burned shares up.
    function withdraw(uint256 amount) external returns (uint256 shares);
    /// @notice Redeem all caller shares, rounding assets down.
    function withdrawAll() external returns (uint256 amount);
    /// @notice Accrue outstanding debt at the current annual rate.
    function accrueInterest() external;
    /// @notice Pending-interest-inclusive lender assets, rounded down.
    function balanceOf(address user) external view returns (uint256);
    /// @notice Accounted liquidity; unsolicited transfers are excluded.
    function availableLiquidity() external view returns (uint256);
    /// @notice Snapshot including pending interest.
    function getMarketState() external view returns (MarketState memory);
}
