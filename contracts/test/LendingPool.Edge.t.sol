// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ArcadiaBase} from "./Arcadia.Base.t.sol";
import {LendingPool} from "../LendingPool.sol";
import {FeeOnTransferToken} from "./MockUSDC.sol";

contract LendingPoolEdgeTest is ArcadiaBase {
    uint256 internal constant SCALE = 1e6;

    // ------------------------------------------------------------ rounding / dust
    function test_OneWeiSupply_AndWithdraw() public {
        uint256 shares = _supply(alice, 1);
        assertEq(shares, SCALE);
        assertEq(pool.balanceOf(alice), 1);
        assertEq(pool.totalSupplied(), 1);

        vm.prank(alice);
        pool.withdraw(1);
        assertEq(pool.totalSupplied(), 0);
        assertEq(pool.totalSupplyShares(), 0);
        assertEq(pool.balanceOf(alice), 0);
    }

    function test_OneWeiSupply_WithdrawAll() public {
        _supply(alice, 1);
        vm.prank(alice);
        assertEq(pool.withdrawAll(), 1);
    }

    function test_ManyOneWeiDeposits_NoValueCreated() public {
        for (uint256 i; i < 20; i++) {
            _supply(alice, 1);
        }
        assertEq(pool.balanceOf(alice), 20);
        assertEq(pool.totalSupplied(), 20);
        vm.prank(alice);
        assertEq(pool.withdrawAll(), 20);
        assertEq(usdc.balanceOf(address(pool)), 0);
    }

    function test_DustAfterInterest_NeverOverpays() public {
        _supply(alice, 1000e6);
        _supply(bob, 3);
        _borrow(500e6);
        vm.warp(block.timestamp + 123 days + 17);
        pool.accrueInterest();
        // sum of claims never exceeds accounted supply
        assertLe(pool.balanceOf(alice) + pool.balanceOf(bob), pool.totalSupplied());
        // tiny holder cannot withdraw more than their claim
        uint256 bobClaim = pool.balanceOf(bob);
        vm.prank(bob);
        vm.expectRevert(LendingPool.InsufficientLiquidity.selector);
        pool.withdraw(bobClaim + 1);
    }

    // ------------------------------------------------------------ donations / inflation attack
    function test_Donation_BeforeFirstDeposit_Ignored() public {
        _donate(address(pool), 1_000_000e6);
        assertEq(pool.totalSupplied(), 0);
        assertEq(pool.availableLiquidity(), 0);
        uint256 shares = _supply(alice, 100e6);
        assertEq(shares, 100e6 * SCALE);
        assertEq(pool.balanceOf(alice), 100e6);
    }

    function test_InflationAttack_FirstDepositorPlusDonation_Fails() public {
        // attacker: 1 wei deposit, then donate a huge amount to skew the exchange rate
        _supply(attacker, 1);
        _donate(address(pool), 1_000_000e6);
        assertEq(pool.balanceOf(attacker), 1, "donation must not inflate attacker claim");

        // victim deposit still mints a fair number of shares
        uint256 victimShares = _supply(alice, 999e6);
        assertEq(victimShares, 999e6 * SCALE);
        assertEq(pool.balanceOf(alice), 999e6);
        assertEq(pool.balanceOf(attacker), 1);

        // attacker cannot extract victim funds
        vm.prank(attacker);
        assertEq(pool.withdrawAll(), 1);
        vm.prank(alice);
        assertEq(pool.withdrawAll(), 999e6);
    }

    function test_InflationAttack_SmallVictimDeposit() public {
        _supply(attacker, 1);
        _donate(address(pool), 10_000_000e6);
        // even a 1 wei victim is not rounded to zero shares
        uint256 s = _supply(alice, 1);
        assertEq(s, SCALE);
        assertEq(pool.balanceOf(alice), 1);
    }

    function test_DonationMidLife_NoRepricing() public {
        _supply(alice, 500e6);
        _supply(bob, 500e6);
        _donate(address(pool), 123e6);
        assertEq(pool.balanceOf(alice), 500e6);
        assertEq(pool.balanceOf(bob), 500e6);
        assertEq(pool.totalSupplied(), 1000e6);
        assertEq(pool.availableLiquidity(), 1000e6);
    }

    // ------------------------------------------------------------ sweepUnaccounted
    function test_Sweep_RecoversOnlyDonation() public {
        _supply(alice, 1000e6);
        _donate(address(pool), 50e6);

        vm.expectEmit(true, false, false, true, address(pool));
        emit LendingPool.UnaccountedSwept(treasury, 50e6);
        vm.prank(admin);
        uint256 swept = pool.sweepUnaccounted(treasury);

        assertEq(swept, 50e6);
        assertEq(usdc.balanceOf(treasury), 50e6);
        assertEq(usdc.balanceOf(address(pool)), 1000e6);
        assertEq(pool.balanceOf(alice), 1000e6);
        assertEq(pool.totalSupplied(), 1000e6);
    }

    function test_Sweep_NothingToSweepReverts() public {
        _supply(alice, 1000e6);
        vm.prank(admin);
        vm.expectRevert(LendingPool.ZeroAmount.selector);
        pool.sweepUnaccounted(treasury);
    }

    function test_Sweep_ZeroRecipientReverts() public {
        vm.prank(admin);
        vm.expectRevert(LendingPool.ZeroAddress.selector);
        pool.sweepUnaccounted(address(0));
    }

    function test_Sweep_DoesNotTouchOutstandingLoanOrReserves() public {
        _supply(alice, 1000e6);
        _borrow(500e6);
        vm.warp(block.timestamp + YEAR);
        _donate(address(pool), 7e6);
        vm.prank(admin);
        uint256 swept = pool.sweepUnaccounted(treasury);
        // cash 500e6 equals accounted liquidity 500e6, so only the donation is swept
        assertEq(swept, 7e6);
        assertEq(usdc.balanceOf(address(pool)), pool.availableLiquidity());
    }

    // ------------------------------------------------------------ fee-on-transfer (unsupported)
    function _feePool() internal returns (LendingPool p, FeeOnTransferToken t) {
        t = new FeeOnTransferToken();
        p = new LendingPool(address(t), address(rm), address(irm), admin, RF);
        address[3] memory us = [alice, bob, carol];
        for (uint256 i; i < us.length; i++) {
            t.mint(us[i], 10_000e6);
            vm.prank(us[i]);
            t.approve(address(p), type(uint256).max);
        }
    }

    function test_FeeOnTransfer_PoolOverCreditsDepositor_SweepDetectsDeficit() public {
        (LendingPool p, FeeOnTransferToken t) = _feePool();
        vm.prank(alice);
        p.supply(1000e6);

        // accounting credits the full amount while only 99% arrived => documented unsupported asset
        assertEq(p.totalSupplied(), 1000e6);
        assertEq(t.balanceOf(address(p)), 990e6);

        vm.prank(admin);
        vm.expectRevert(LendingPool.AccountingDeficit.selector);
        p.sweepUnaccounted(treasury);
    }

    function test_FeeOnTransfer_LastWithdrawerCannotExit() public {
        (LendingPool p, FeeOnTransferToken t) = _feePool();
        vm.prank(alice);
        p.supply(1000e6);
        vm.prank(bob);
        p.supply(1000e6);
        assertEq(t.balanceOf(address(p)), 1980e6);

        vm.prank(alice);
        p.withdrawAll(); // first exit succeeds (sent 1000e6, alice nets 990e6)
        assertEq(t.balanceOf(address(p)), 980e6);

        vm.prank(bob);
        vm.expectRevert(); // pool is short: ERC20InsufficientBalance
        p.withdrawAll();
    }

    function test_FeeOnTransfer_FactoryAllows6DecimalFeeToken_AdminMustVet() public {
        FeeOnTransferToken t = new FeeOnTransferToken();
        vm.prank(admin);
        factory.addSupportedAsset(address(t)); // no on-chain fee detection (documented)
        assertTrue(factory.isSupportedAsset(address(t)));
    }

    // ------------------------------------------------------------ reentrancy-lock sanity
    function test_NoPublicBorrowEntryPoint() public {
        // The production pool exposes no borrow / repay selectors.
        bytes memory data = abi.encodeWithSignature("borrow(uint256)", 1e6);
        _supply(alice, 10e6);
        LendingPool plain = new LendingPool(address(usdc), address(rm), address(irm), admin, RF);
        (bool ok,) = address(plain).call(data);
        assertFalse(ok);
        (ok,) = address(plain).call(abi.encodeWithSignature("repay(uint256)", 1e6));
        assertFalse(ok);
    }
}
