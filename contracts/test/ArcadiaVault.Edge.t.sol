// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ArcadiaBase} from "./Arcadia.Base.t.sol";
import {ArcadiaVault} from "../ArcadiaVault.sol";
import {FeeOnTransferToken} from "./MockUSDC.sol";

contract ArcadiaVaultEdgeTest is ArcadiaBase {
    uint256 internal constant SCALE = 1e6;

    // ------------------------------------------------------------ donations
    function test_Donation_DoesNotChangePriceOrAccounting() public {
        _vaultDeposit(alice, 1000e6);
        _donate(address(vault), 500e6);

        assertEq(vault.totalAssets(), 1000e6);
        assertEq(vault.accountedAssets(), 1000e6);
        assertEq(vault.sharePrice(), 1e6);
        assertEq(vault.convertToAssets(vault.balanceOf(alice)), 1000e6);
        assertEq(usdc.balanceOf(address(vault)), 1500e6);

        uint256 bobShares = _vaultDeposit(bob, 1000e6);
        assertEq(bobShares, 1000e6 * SCALE, "donation must not dilute newcomers");

        uint256 sh = vault.balanceOf(alice);
        vm.prank(alice);
        assertEq(vault.redeem(sh, alice, alice), 1000e6);
    }

    function test_Donation_BeforeFirstDeposit_Ignored() public {
        _donate(address(vault), 1_000_000e6);
        assertEq(vault.totalAssets(), 0);
        assertEq(vault.totalSupply(), 0);
        uint256 shares = _vaultDeposit(alice, 100e6);
        assertEq(shares, 100e6 * SCALE);
    }

    function test_Sweep_RecoversOnlyDonation() public {
        _vaultDeposit(alice, 1000e6);
        _donate(address(vault), 25e6);

        vm.expectEmit(true, false, false, true, address(vault));
        emit ArcadiaVault.UnaccountedSwept(treasury, 25e6);
        vm.prank(admin);
        uint256 swept = vault.sweepUnaccounted(treasury);

        assertEq(swept, 25e6);
        assertEq(usdc.balanceOf(treasury), 25e6);
        assertEq(usdc.balanceOf(address(vault)), 1000e6);
        assertEq(vault.totalAssets(), 1000e6);
    }

    function test_Sweep_NothingToSweepAndZeroAddressRevert() public {
        _vaultDeposit(alice, 10e6);
        vm.startPrank(admin);
        vm.expectRevert(ArcadiaVault.ZeroAmount.selector);
        vault.sweepUnaccounted(treasury);
        vm.expectRevert(ArcadiaVault.ZeroAddress.selector);
        vault.sweepUnaccounted(address(0));
        vm.stopPrank();
    }

    // ------------------------------------------------------------ inflation attack
    function test_InflationAttack_Fails() public {
        _vaultDeposit(attacker, 1);
        _donate(address(vault), 1_000_000e6);

        uint256 victimShares = _vaultDeposit(alice, 999e6);
        assertEq(victimShares, 999e6 * SCALE);
        assertEq(vault.convertToAssets(vault.balanceOf(alice)), 999e6);
        assertEq(vault.convertToAssets(vault.balanceOf(attacker)), 1);

        uint256 shA = vault.balanceOf(attacker);
        uint256 shV = vault.balanceOf(alice);
        vm.prank(attacker);
        assertEq(vault.redeem(shA, attacker, attacker), 1);
        vm.prank(alice);
        assertEq(vault.redeem(shV, alice, alice), 999e6);
    }

    function test_InflationAttack_OneWeiVictimNotZeroShares() public {
        _vaultDeposit(attacker, 1);
        _donate(address(vault), 10_000_000e6);
        assertEq(_vaultDeposit(alice, 1), SCALE);
    }

    // ------------------------------------------------------------ rounding
    function test_OneWeiDeposit_RoundTrip() public {
        assertEq(_vaultDeposit(alice, 1), SCALE);
        assertEq(vault.totalAssets(), 1);
        vm.prank(alice);
        assertEq(vault.redeem(SCALE, alice, alice), 1);
        assertEq(vault.totalAssets(), 0);
        assertEq(vault.totalSupply(), 0);
    }

    function test_SubWeiShares_RedeemReverts() public {
        _vaultDeposit(alice, 1);
        vm.prank(alice);
        vm.expectRevert(ArcadiaVault.ZeroAmount.selector);
        vault.redeem(SCALE - 1, alice, alice);
    }

    function test_FractionalRedeem_LeavesDustButNeverOverpays() public {
        _vaultDeposit(alice, 2); // 2e6 shares
        vm.prank(alice);
        uint256 out = vault.redeem(1_500_000, alice, alice); // floor(1.5) = 1 wei
        assertEq(out, 1);
        assertEq(vault.balanceOf(alice), 500_000);
        assertEq(vault.totalAssets(), 1);
        // conservation law
        assertLe(vault.convertToAssets(vault.totalSupply()), vault.totalAssets());
        assertLe(vault.totalAssets(), usdc.balanceOf(address(vault)));
    }

    function test_MintFractional_RoundsUpAssetsCost() public {
        vm.prank(alice);
        uint256 cost = vault.mint(1_500_000, alice);
        assertEq(cost, 2); // ceil
        assertEq(vault.balanceOf(alice), 1_500_000);
        assertEq(vault.totalAssets(), 2);
        vm.prank(alice);
        uint256 back = vault.redeem(1_500_000, alice, alice);
        assertLe(back, cost, "round trip never profits");
    }

    // ------------------------------------------------------------ fee-on-transfer (unsupported)
    function test_FeeOnTransfer_VaultOverCredits_SweepDetectsDeficit() public {
        FeeOnTransferToken t = new FeeOnTransferToken();
        ArcadiaVault v = new ArcadiaVault(address(t), address(rm), admin, "Fee", "FEE");
        t.mint(alice, 1000e6);
        vm.startPrank(alice);
        t.approve(address(v), type(uint256).max);
        v.deposit(1000e6, alice);
        vm.stopPrank();

        assertEq(v.totalAssets(), 1000e6);
        assertEq(t.balanceOf(address(v)), 990e6);

        vm.prank(admin);
        vm.expectRevert(ArcadiaVault.AccountingDeficit.selector);
        v.sweepUnaccounted(treasury);

        // full withdrawal is impossible: vault is insolvent by the fee
        uint256 sh = v.balanceOf(alice);
        vm.prank(alice);
        vm.expectRevert();
        v.redeem(sh, alice, alice);
    }
}
