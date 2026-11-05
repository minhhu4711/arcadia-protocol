// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ArcadiaBase} from "./Arcadia.Base.t.sol";
import {LendingPool} from "../LendingPool.sol";
import {ILendingPool} from "../interfaces/ILendingPool.sol";
import {LendingPoolHarness} from "./LendingPoolHarness.sol";

contract LendingPoolInterestTest is ArcadiaBase {
    uint256 internal t0;

    function setUp() public override {
        super.setUp();
        t0 = block.timestamp;
        _supply(alice, 1000e6);
    }

    function _newPool(uint256 rf) internal returns (LendingPoolHarness p) {
        p = new LendingPoolHarness(address(usdc), address(rm), address(irm), admin, rf);
        vm.startPrank(alice);
        usdc.approve(address(p), type(uint256).max);
        p.supply(1000e6);
        vm.stopPrank();
    }

    // ------------------------------------------------------------ borrow / repay hooks
    function test_RecordBorrow_UpdatesBorrowedAndLiquidity() public {
        _borrow(500e6);
        assertEq(pool.totalBorrowed(), 500e6);
        assertEq(pool.availableLiquidity(), 500e6);
        assertEq(pool.totalSupplied(), 1000e6);
        assertEq(usdc.balanceOf(borrower), 10_000_000e6 + 500e6);
        assertEq(pool.utilization(), 0.5e18);
    }

    function test_RecordBorrow_Reverts() public {
        vm.expectRevert(LendingPool.ZeroAmount.selector);
        pool.exposed_recordBorrow(0);
        vm.expectRevert(LendingPool.InsufficientLiquidity.selector);
        pool.exposed_recordBorrow(1000e6 + 1);
    }

    function test_RecordRepay_Reverts() public {
        _borrow(100e6);
        vm.expectRevert(LendingPool.ZeroAmount.selector);
        pool.exposed_recordRepay(0);
        vm.expectRevert(LendingPool.InvalidRepayment.selector);
        pool.exposed_recordRepay(100e6 + 1);
    }

    function test_RecordRepay_ReducesBorrowed() public {
        _borrow(100e6);
        pool.repayFrom(borrower, 40e6);
        assertEq(pool.totalBorrowed(), 60e6);
        assertEq(pool.availableLiquidity(), 940e6);
        assertEq(usdc.balanceOf(address(pool)), 940e6);
    }

    // ------------------------------------------------------------ accrual vs hand-computed values
    function test_Accrual_OneYear_HandComputed() public {
        _borrow(500e6); // util 50% => rate = 2% + 0.5/0.8*4% = 4.5%
        assertEq(pool.borrowRate(), 0.045e18);

        vm.warp(t0 + YEAR);
        // interest = 500e6 * 4.5% = 22.5e6 ; reserve cut 10% = 2.25e6 ; lenders get 20.25e6
        vm.expectEmit(false, false, false, true, address(pool));
        emit LendingPool.InterestAccrued(22.5e6, 2.25e6, 0.045e18, 522.5e6, 1020.25e6, t0 + YEAR);
        pool.accrueInterest();

        assertEq(pool.totalBorrowed(), 522.5e6);
        assertEq(pool.totalSupplied(), 1020.25e6);
        assertEq(pool.totalReserves(), 2.25e6);
        assertEq(pool.lastAccrual(), t0 + YEAR);
        // cash conservation: accrual does not change liquidity
        assertEq(pool.availableLiquidity(), 500e6);
        // alice's claim (virtual-share rounding costs at most a couple of wei)
        assertApproxEqAbs(pool.balanceOf(alice), 1020.25e6, 2);
        assertLe(pool.balanceOf(alice), 1020.25e6 + 1);
    }

    function test_Accrual_HalfYear_HandComputed() public {
        _borrow(500e6);
        vm.warp(t0 + YEAR / 2);
        pool.accrueInterest();
        assertEq(pool.totalBorrowed(), 511.25e6);
        assertEq(pool.totalReserves(), 1.125e6);
        assertEq(pool.totalSupplied(), 1000e6 + 10.125e6);
    }

    function test_Accrual_OneDay_MatchesFormula() public {
        _borrow(500e6);
        vm.warp(t0 + 1 days);
        uint256 expected = Math.mulDiv(500e6, 0.045e18 * 1 days, YEAR * WAD);
        pool.accrueInterest();
        assertEq(pool.totalBorrowed(), 500e6 + expected);
        assertEq(pool.totalReserves(), Math.mulDiv(expected, RF, WAD));
        assertGt(expected, 0);
    }

    function test_Accrual_SecondPeriodUsesNewUtilization() public {
        _borrow(500e6);
        vm.warp(t0 + YEAR);
        pool.accrueInterest();

        uint256 borrowedBefore = pool.totalBorrowed();
        uint256 rate2 = irm.getBorrowRate(irm.utilization(pool.availableLiquidity(), borrowedBefore));
        assertGt(rate2, 0.045e18); // utilization went up
        vm.warp(t0 + 2 * YEAR);
        pool.accrueInterest();
        assertEq(pool.totalBorrowed(), borrowedBefore + Math.mulDiv(borrowedBefore, rate2, WAD));
    }

    function test_Accrual_NoBorrows_NoInterest() public {
        vm.warp(t0 + 5 * YEAR);
        pool.accrueInterest();
        assertEq(pool.totalSupplied(), 1000e6);
        assertEq(pool.totalReserves(), 0);
        assertEq(pool.totalBorrowed(), 0);
        assertEq(pool.lastAccrual(), t0 + 5 * YEAR);
        assertEq(pool.balanceOf(alice), 1000e6);
    }

    function test_Accrual_SameTimestamp_Idempotent() public {
        _borrow(500e6);
        vm.warp(t0 + 100 days);
        pool.accrueInterest();
        uint256 b = pool.totalBorrowed();
        uint256 s = pool.totalSupplied();
        pool.accrueInterest();
        pool.accrueInterest();
        assertEq(pool.totalBorrowed(), b);
        assertEq(pool.totalSupplied(), s);
    }

    function test_Accrual_TriggeredBySupplyAndWithdraw() public {
        _borrow(500e6);
        vm.warp(t0 + YEAR);
        _supply(bob, 100e6); // accrues first
        assertEq(pool.totalBorrowed(), 522.5e6);
        assertEq(pool.lastAccrual(), t0 + YEAR);
    }

    function test_PendingInterestVisibleInViewsBeforeAccrual() public {
        _borrow(500e6);
        vm.warp(t0 + YEAR);
        // views include pending interest
        uint256 viewBal = pool.balanceOf(alice);
        ILendingPool.MarketState memory s = pool.getMarketState();
        assertEq(s.supplied, 1020.25e6);
        assertEq(s.borrowed, 522.5e6);
        assertEq(s.reserves, 2.25e6);
        // stored state still stale
        assertEq(pool.totalBorrowed(), 500e6);
        pool.accrueInterest();
        assertEq(pool.balanceOf(alice), viewBal);
    }

    // ------------------------------------------------------------ reserve cut variants
    function test_ReserveFactor_Zero_AllInterestToLenders() public {
        LendingPoolHarness p = _newPool(0);
        p.borrowTo(borrower, 500e6);
        vm.warp(t0 + YEAR);
        p.accrueInterest();
        assertEq(p.totalReserves(), 0);
        assertEq(p.totalSupplied(), 1022.5e6);
    }

    function test_ReserveFactor_Max_HalfInterestToReserves() public {
        LendingPoolHarness p = _newPool(0.5e18);
        p.borrowTo(borrower, 500e6);
        vm.warp(t0 + YEAR);
        p.accrueInterest();
        assertEq(p.totalReserves(), 11.25e6);
        assertEq(p.totalSupplied(), 1011.25e6);
    }

    // ------------------------------------------------------------ rates through the pool (kink)
    function test_Rates_ZeroUtilization() public view {
        assertEq(pool.utilization(), 0);
        assertEq(pool.borrowRate(), 0.02e18);
        assertEq(pool.supplyRate(), 0);
    }

    function test_Rates_BelowKink_40Percent() public {
        _borrow(400e6);
        assertEq(pool.utilization(), 0.4e18);
        assertEq(pool.borrowRate(), 0.04e18);
    }

    function test_Rates_AtOptimal_80Percent() public {
        _borrow(800e6);
        assertEq(pool.utilization(), 0.8e18);
        assertEq(pool.borrowRate(), 0.06e18);
        assertEq(pool.supplyRate(), 0.0432e18); // 6% * 80% * (1 - 10%)
    }

    function test_Rates_FullUtilization_100Percent() public {
        _borrow(1000e6);
        assertEq(pool.utilization(), WAD);
        assertEq(pool.borrowRate(), 0.81e18);
        assertEq(pool.availableLiquidity(), 0);
    }

    function test_FullUtilization_OneYear_HandComputed() public {
        _borrow(1000e6);
        vm.warp(t0 + YEAR);
        pool.accrueInterest();
        assertEq(pool.totalBorrowed(), 1810e6);
        assertEq(pool.totalReserves(), 81e6);
        assertEq(pool.totalSupplied(), 1729e6);
        assertEq(pool.availableLiquidity(), 0);
        // lenders are fully illiquid: cannot exit
        vm.prank(alice);
        vm.expectRevert(LendingPool.InsufficientLiquidity.selector);
        pool.withdraw(1);
    }

    // ------------------------------------------------------------ reserves admin
    function test_WithdrawReserves_Valid() public {
        _borrow(500e6);
        vm.warp(t0 + YEAR);
        vm.expectEmit(true, false, false, true, address(pool));
        emit LendingPool.ReservesWithdrawn(treasury, 2.25e6);
        vm.prank(admin);
        pool.withdrawReserves(treasury, 2.25e6);
        assertEq(usdc.balanceOf(treasury), 2.25e6);
        assertEq(pool.totalReserves(), 0);
        assertEq(pool.availableLiquidity(), 497.75e6);
    }

    function test_WithdrawReserves_Reverts() public {
        _borrow(500e6);
        vm.warp(t0 + YEAR);
        vm.startPrank(admin);
        vm.expectRevert(LendingPool.ZeroAddress.selector);
        pool.withdrawReserves(address(0), 1);
        vm.expectRevert(LendingPool.ZeroAmount.selector);
        pool.withdrawReserves(treasury, 0);
        vm.expectRevert(LendingPool.InsufficientReserves.selector);
        pool.withdrawReserves(treasury, 2.25e6 + 1);
        vm.stopPrank();
    }

    function test_WithdrawReserves_BoundedByLiquidity() public {
        _borrow(1000e6); // 100% util, liquidity 0
        vm.warp(t0 + 30 days);
        vm.prank(admin);
        vm.expectRevert(LendingPool.InsufficientLiquidity.selector);
        pool.withdrawReserves(treasury, 1);
    }

    // ------------------------------------------------------------ lender outcome
    function test_LenderEarnsInterest_AfterRepay() public {
        _borrow(500e6);
        vm.warp(t0 + YEAR);
        pool.accrueInterest();
        pool.repayFrom(borrower, 522.5e6);
        assertEq(pool.totalBorrowed(), 0);

        vm.prank(alice);
        uint256 out = pool.withdrawAll();
        assertApproxEqAbs(out, 1020.25e6, 2);
        assertGe(usdc.balanceOf(address(pool)), pool.totalReserves());
        // reserves remain withdrawable after lender exit
        uint256 res = pool.totalReserves();
        vm.prank(admin);
        pool.withdrawReserves(treasury, res);
    }

    function test_LateDepositor_GetsFewerSharesAfterInterest() public {
        _borrow(500e6);
        vm.warp(t0 + YEAR);
        uint256 bobShares = _supply(bob, 1000e6);
        assertLt(bobShares, 1000e6 * 1e6);
        assertApproxEqAbs(pool.balanceOf(bob), 1000e6, 1);
        assertLe(pool.balanceOf(bob), 1000e6);
        // alice keeps her earned interest, bob did not capture it
        assertApproxEqAbs(pool.balanceOf(alice), 1020.25e6, 2);
    }

    function test_WithdrawAllAfterInterest_NeverBelowPrincipal() public {
        _borrow(300e6);
        vm.warp(t0 + 200 days);
        pool.accrueInterest();
        assertGe(pool.balanceOf(alice), 1000e6);
    }
}
