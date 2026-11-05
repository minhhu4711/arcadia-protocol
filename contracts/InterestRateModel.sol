// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IInterestRateModel} from "./interfaces/IInterestRateModel.sol";

/// @notice Immutable kink model. Rates and utilization use WAD (1e18 = 100%).
/// @dev Annualization uses SECONDS_PER_YEAR = 365 days. Pools accrue linearly:
/// interest = borrows * annualRate * dt / (SECONDS_PER_YEAR * 1e18).
/// No rate is a per-second rate, and there is no automatic compounding within one accrual interval.
contract InterestRateModel is AccessControl, IInterestRateModel {
    uint256 public constant WAD = 1e18;
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public immutable baseRate;
    uint256 public immutable optimalUtilization;
    uint256 public immutable slope1;
    uint256 public immutable slope2;

    error ZeroAddress();
    error InvalidUtilization();
    error InvalidReserveFactor();
    error ExcessiveRate();

    /// @notice Initialize immutable annual WAD rates; admin receives DEFAULT_ADMIN_ROLE only.
    /// @dev Explicit admin is added to satisfy the protocol-wide constructor requirement.
    constructor(address admin, uint256 baseRate_, uint256 optimalUtilization_, uint256 slope1_, uint256 slope2_) {
        if (admin == address(0)) revert ZeroAddress();
        if (optimalUtilization_ == 0 || optimalUtilization_ >= WAD) revert InvalidUtilization();
        if (baseRate_ > 10e18 || slope1_ > 10e18 || slope2_ > 10e18) revert ExcessiveRate();
        if (baseRate_ + slope1_ + slope2_ > 10e18) revert ExcessiveRate();
        baseRate = baseRate_;
        optimalUtilization = optimalUtilization_;
        slope1 = slope1_;
        slope2 = slope2_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /// @inheritdoc IInterestRateModel
    function utilization(uint256 cash, uint256 borrows) public pure override returns (uint256) {
        if (borrows == 0) return 0;
        return Math.mulDiv(borrows, WAD, cash + borrows);
    }

    /// @inheritdoc IInterestRateModel
    function getBorrowRate(uint256 utilizationWad) public view override returns (uint256) {
        if (utilizationWad > WAD) revert InvalidUtilization();
        if (utilizationWad <= optimalUtilization) {
            return baseRate + Math.mulDiv(utilizationWad, slope1, optimalUtilization);
        }
        return baseRate + slope1 + Math.mulDiv(utilizationWad - optimalUtilization, slope2, WAD - optimalUtilization);
    }

    /// @inheritdoc IInterestRateModel
    function getSupplyRate(uint256 utilizationWad, uint256 reserveFactorWad) external view override returns (uint256) {
        if (reserveFactorWad > WAD) revert InvalidReserveFactor();
        return Math.mulDiv(Math.mulDiv(getBorrowRate(utilizationWad), utilizationWad, WAD), WAD - reserveFactorWad, WAD);
    }
}
