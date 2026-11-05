// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ArcadiaBase} from "./Arcadia.Base.t.sol";
import {InterestRateModel} from "../InterestRateModel.sol";

contract InterestRateModelTest is ArcadiaBase {
    function test_Constructor_StoresParamsAndAdmin() public view {
        assertEq(irm.baseRate(), BASE);
        assertEq(irm.optimalUtilization(), OPT);
        assertEq(irm.slope1(), S1);
        assertEq(irm.slope2(), S2);
        assertTrue(irm.hasRole(DEFAULT_ADMIN_ROLE, admin));
    }

    function test_Constructor_ZeroAdminReverts() public {
        vm.expectRevert(InterestRateModel.ZeroAddress.selector);
        new InterestRateModel(address(0), BASE, OPT, S1, S2);
    }

    function test_Constructor_InvalidOptimalReverts() public {
        vm.expectRevert(InterestRateModel.InvalidUtilization.selector);
        new InterestRateModel(admin, BASE, 0, S1, S2);
        vm.expectRevert(InterestRateModel.InvalidUtilization.selector);
        new InterestRateModel(admin, BASE, WAD, S1, S2);
        vm.expectRevert(InterestRateModel.InvalidUtilization.selector);
        new InterestRateModel(admin, BASE, WAD + 1, S1, S2);
    }

    function test_Constructor_ExcessiveRatesRevert() public {
        vm.expectRevert(InterestRateModel.ExcessiveRate.selector);
        new InterestRateModel(admin, 10e18 + 1, OPT, 0, 0);
        vm.expectRevert(InterestRateModel.ExcessiveRate.selector);
        new InterestRateModel(admin, 0, OPT, 10e18 + 1, 0);
        vm.expectRevert(InterestRateModel.ExcessiveRate.selector);
        new InterestRateModel(admin, 0, OPT, 0, 10e18 + 1);
        vm.expectRevert(InterestRateModel.ExcessiveRate.selector);
        new InterestRateModel(admin, 5e18, OPT, 3e18, 2e18 + 1); // sum > 10e18
        // sum == 10e18 is fine
        new InterestRateModel(admin, 5e18, OPT, 3e18, 2e18);
    }

    function test_Utilization() public view {
        assertEq(irm.utilization(1000e6, 0), 0);
        assertEq(irm.utilization(0, 0), 0);
        assertEq(irm.utilization(500e6, 500e6), 0.5e18);
        assertEq(irm.utilization(0, 1000e6), WAD);
        assertEq(irm.utilization(200e6, 800e6), 0.8e18);
        assertEq(irm.utilization(300e6, 100e6), 0.25e18);
    }

    function test_BorrowRate_AtZeroUtilization_IsBase() public view {
        assertEq(irm.getBorrowRate(0), BASE);
    }

    function test_BorrowRate_BelowKink_Linear() public view {
        assertEq(irm.getBorrowRate(0.4e18), BASE + S1 / 2); // 0.04
        assertEq(irm.getBorrowRate(0.2e18), BASE + S1 / 4); // 0.03
    }

    function test_BorrowRate_AtOptimal() public view {
        assertEq(irm.getBorrowRate(OPT), BASE + S1); // 0.06
    }

    function test_BorrowRate_AboveKink_Steep() public view {
        // halfway between 80% and 100% => base + slope1 + slope2/2
        assertEq(irm.getBorrowRate(0.9e18), BASE + S1 + S2 / 2);
    }

    function test_BorrowRate_AtFullUtilization() public view {
        assertEq(irm.getBorrowRate(WAD), BASE + S1 + S2); // 0.81
    }

    function test_BorrowRate_Above100PercentReverts() public {
        vm.expectRevert(InterestRateModel.InvalidUtilization.selector);
        irm.getBorrowRate(WAD + 1);
    }

    function test_SupplyRate() public view {
        // u=0 => 0
        assertEq(irm.getSupplyRate(0, RF), 0);
        // u=0.8 => 0.06 * 0.8 * 0.9 = 0.0432
        assertEq(irm.getSupplyRate(OPT, RF), 0.0432e18);
        // u=1, rf=0 => borrow rate
        assertEq(irm.getSupplyRate(WAD, 0), BASE + S1 + S2);
        // rf=100% => 0
        assertEq(irm.getSupplyRate(OPT, WAD), 0);
    }

    function test_SupplyRate_ReserveFactorAbove100Reverts() public {
        vm.expectRevert(InterestRateModel.InvalidReserveFactor.selector);
        irm.getSupplyRate(OPT, WAD + 1);
    }

    function testFuzz_BorrowRate_MonotonicAndBounded(uint256 u1, uint256 u2) public view {
        u1 = bound(u1, 0, WAD);
        u2 = bound(u2, u1, WAD);
        uint256 r1 = irm.getBorrowRate(u1);
        uint256 r2 = irm.getBorrowRate(u2);
        assertLe(r1, r2);
        assertGe(r1, BASE);
        assertLe(r2, BASE + S1 + S2);
    }

    function testFuzz_Utilization_InRange(uint128 cash, uint128 borrows) public view {
        uint256 u = irm.utilization(cash, borrows);
        assertLe(u, WAD);
        if (borrows == 0) assertEq(u, 0);
    }
}
