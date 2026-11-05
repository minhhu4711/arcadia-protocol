// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ArcadiaBase} from "./Arcadia.Base.t.sol";

contract ArcadiaFuzzTest is ArcadiaBase {
    // ------------------------------------------------------------ LendingPool
    function testFuzz_Pool_RoundTrip_NeverProfits(uint256 amount) public {
        amount = bound(amount, 1, MAX_DEP);
        uint256 before_ = usdc.balanceOf(alice);
        _supply(alice, amount);
        vm.prank(alice);
        uint256 out = pool.withdrawAll();
        assertLe(out, amount);
        assertEq(out, amount, "no interest, no loss expected");
        assertEq(usdc.balanceOf(alice), before_);
        assertEq(pool.totalSupplied(), 0);
    }

    function testFuzz_Pool_PartialWithdraw_NeverExceedsDeposit(uint256 amount, uint256 part) public {
        amount = bound(amount, 1, MAX_DEP);
        part = bound(part, 1, amount);
        _supply(alice, amount);
        vm.prank(alice);
        pool.withdraw(part);
        assertEq(pool.balanceOf(alice), amount - part);
        assertEq(usdc.balanceOf(address(pool)), amount - part);
    }

    function testFuzz_Pool_OverWithdrawReverts(uint256 amount, uint256 extra) public {
        amount = bound(amount, 1, MAX_DEP);
        extra = bound(extra, 1, MAX_DEP);
        _supply(alice, amount);
        _supply(bob, MAX_DEP); // ample liquidity
        vm.prank(alice);
        vm.expectRevert();
        pool.withdraw(amount + extra);
    }

    function testFuzz_Pool_TwoUsersWithDonation_NoExtraction(uint256 a, uint256 b, uint256 donation) public {
        a = bound(a, 1, MAX_DEP);
        b = bound(b, 1, MAX_DEP);
        donation = bound(donation, 0, 1e15);
        _supply(attacker, a);
        _donate(address(pool), donation);
        _supply(alice, b);

        vm.prank(alice);
        uint256 outA = pool.withdrawAll();
        vm.prank(attacker);
        uint256 outB = pool.withdrawAll();
        assertLe(outA, b);
        assertLe(outB, a);
        assertEq(outA, b);
        assertEq(outB, a);
        assertEq(usdc.balanceOf(address(pool)), donation);
    }

    function testFuzz_Pool_PreviewRoundTrip_NeverProfits(uint256 assets) public {
        _supply(bob, 1000e6);
        assets = bound(assets, 0, 1e15);
        assertLe(pool.previewRedeem(pool.previewSupply(assets)), assets);
        assertGe(pool.previewRedeem(pool.previewWithdraw(assets)), assets);
    }

    function testFuzz_Pool_AccrualMonotonic(uint256 borrowAmt, uint256 dt1, uint256 dt2) public {
        _supply(alice, 1000e6);
        borrowAmt = bound(borrowAmt, 1, 1000e6);
        dt1 = bound(dt1, 1, 5 * YEAR);
        dt2 = bound(dt2, 1, 5 * YEAR);
        _borrow(borrowAmt);

        uint256 liq = pool.availableLiquidity();
        uint256 b0 = pool.totalBorrowed();
        uint256 s0 = pool.totalSupplied();
        uint256 r0 = pool.totalReserves();

        vm.warp(block.timestamp + dt1);
        pool.accrueInterest();
        assertGe(pool.totalBorrowed(), b0);
        assertGe(pool.totalSupplied(), s0);
        assertGe(pool.totalReserves(), r0);
        assertEq(pool.availableLiquidity(), liq, "accrual never changes cash");

        uint256 b1 = pool.totalBorrowed();
        uint256 s1 = pool.totalSupplied();
        uint256 r1 = pool.totalReserves();
        vm.warp(block.timestamp + dt2);
        pool.accrueInterest();
        assertGe(pool.totalBorrowed(), b1);
        assertGe(pool.totalSupplied(), s1);
        assertGe(pool.totalReserves(), r1);
        assertEq(pool.availableLiquidity(), liq);
        // interest split is exact: lenders + reserves == borrower debt growth
        assertEq(
            (pool.totalSupplied() - s0) + (pool.totalReserves() - r0), pool.totalBorrowed() - b0
        );
    }

    function testFuzz_Pool_LenderNeverLosesPrincipalFromInterest(uint256 borrowAmt, uint256 dt, uint256 lateDeposit)
        public
    {
        _supply(alice, 1000e6);
        borrowAmt = bound(borrowAmt, 1, 1000e6);
        dt = bound(dt, 0, 3 * YEAR);
        lateDeposit = bound(lateDeposit, 1, MAX_DEP);
        _borrow(borrowAmt);
        vm.warp(block.timestamp + dt);
        assertGe(pool.balanceOf(alice), 1000e6);

        _supply(bob, lateDeposit);
        assertLe(pool.balanceOf(bob), lateDeposit, "late depositor cannot gain from others");
        assertGe(pool.balanceOf(alice), 1000e6);
        assertLe(pool.balanceOf(alice) + pool.balanceOf(bob), pool.totalSupplied());
    }

    // ------------------------------------------------------------ Vault
    function testFuzz_Vault_DepositWithdraw_RoundTrip(uint256 amount) public {
        amount = bound(amount, 1, MAX_DEP);
        uint256 before_ = usdc.balanceOf(alice);
        uint256 shares = _vaultDeposit(alice, amount);
        assertEq(shares, amount * 1e6);
        vm.prank(alice);
        vault.withdraw(amount, alice, alice);
        assertEq(usdc.balanceOf(alice), before_);
        assertEq(vault.totalAssets(), 0);
        assertEq(vault.totalSupply(), 0);
    }

    function testFuzz_Vault_MintRedeem_NeverProfits(uint256 shares) public {
        shares = bound(shares, 1e6, MAX_DEP * 1e6);
        uint256 before_ = usdc.balanceOf(alice);
        vm.prank(alice);
        uint256 cost = vault.mint(shares, alice);
        vm.prank(alice);
        uint256 back = vault.redeem(shares, alice, alice);
        assertLe(back, cost);
        assertLe(usdc.balanceOf(alice), before_);
        assertLe(vault.convertToAssets(vault.totalSupply()), vault.totalAssets());
    }

    function testFuzz_Vault_RedeemArbitraryShares_NeverOverpays(uint256 depositAmt, uint256 sharesToRedeem) public {
        depositAmt = bound(depositAmt, 1, MAX_DEP);
        _vaultDeposit(alice, depositAmt);
        _vaultDeposit(bob, 1000e6);
        sharesToRedeem = bound(sharesToRedeem, 1e6, depositAmt * 1e6);
        vm.prank(alice);
        uint256 out = vault.redeem(sharesToRedeem, alice, alice);
        assertLe(out, depositAmt);
        assertEq(out, sharesToRedeem / 1e6);
        assertEq(vault.convertToAssets(vault.balanceOf(bob)), 1000e6);
    }

    function testFuzz_Vault_DonationNeverChangesShares(uint256 amount, uint256 donation) public {
        amount = bound(amount, 1, MAX_DEP);
        donation = bound(donation, 0, 1e15);
        _donate(address(vault), donation);
        assertEq(_vaultDeposit(alice, amount), amount * 1e6);
        assertEq(vault.sharePrice(), 1e6);
        _donate(address(vault), donation);
        assertEq(_vaultDeposit(bob, amount), amount * 1e6);
        assertEq(vault.totalAssets(), 2 * amount);
    }
}
