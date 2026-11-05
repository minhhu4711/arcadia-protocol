// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Future module interface only. Liquidations are NOT live in the MVP.
interface ILiquidationManager {
    /// @notice Future liquidation of unhealthy collateral-backed debt; amounts in token base units.
    function liquidate(address borrower, address market, address collateral, uint256 repayAmount)
        external returns (uint256 collateralSeized);
    /// @notice Future eligibility query; no implementation is provided.
    function isLiquidatable(address borrower) external view returns (bool);
}
