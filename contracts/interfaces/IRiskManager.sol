// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Shared risk controls. All amounts are underlying asset base units.
interface IRiskManager {
    struct MarketRisk {
        bool configured;
        uint256 depositCap;
        uint256 maxDepositPerTx;
        uint256 minDeposit;
        uint256 maxWithdrawPerTx;
        bool withdrawalsPaused;
    }
    /// @notice Whether all user asset movements are paused.
    function protocolPaused() external view returns (bool);
    /// @notice Effective market limits, including the independent withdrawal pause.
    function getRisk(address market) external view returns (MarketRisk memory);
    /// @notice Revert if a proposed deposit violates risk controls.
    function validateDeposit(address market, uint256 amount, uint256 totalAssetsAfter) external view;
    /// @notice Revert if a proposed withdrawal violates risk controls.
    function validateWithdraw(address market, uint256 amount) external view;
    /// @notice Maximum permitted deposit, limited by headroom and the per-transaction maximum.
    function maxDepositFor(address market, uint256 totalAssets) external view returns (uint256);
}
