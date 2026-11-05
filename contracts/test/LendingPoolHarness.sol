// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {LendingPool} from "../LendingPool.sol";

/// @notice Test-only subclass exposing the internal borrow/repay accounting hooks.
contract LendingPoolHarness is LendingPool {
    using SafeERC20 for IERC20;

    constructor(address asset_, address riskManager_, address rateModel_, address admin, uint256 reserveFactorWad_)
        LendingPool(asset_, riskManager_, rateModel_, admin, reserveFactorWad_)
    {}

    /// @dev Accounting only (no token movement).
    function exposed_recordBorrow(uint256 amount) external {
        _recordBorrow(amount);
    }

    /// @dev Accounting only (no token movement).
    function exposed_recordRepay(uint256 amount) external {
        _recordRepay(amount);
    }

    /// @dev Realistic borrow: account then send exactly `amount` out.
    function borrowTo(address to, uint256 amount) external {
        _recordBorrow(amount);
        asset.safeTransfer(to, amount);
    }

    /// @dev Realistic repay: account then pull exactly `amount` in.
    function repayFrom(address from, uint256 amount) external {
        _recordRepay(amount);
        asset.safeTransferFrom(from, address(this), amount);
    }
}
