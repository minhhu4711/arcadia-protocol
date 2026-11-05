// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ArcadiaBase} from "./Arcadia.Base.t.sol";
import {ArcadiaVault} from "../ArcadiaVault.sol";
import {RiskManager} from "../RiskManager.sol";
import {MockDecimalsToken} from "./MockUSDC.sol";

contract ArcadiaVaultTest is ArcadiaBase {
    uint256 internal constant SCALE = 1e6;

    // ------------------------------------------------------------ constructor
    function test_Constructor_State() public view {
        assertEq(vault.asset(), address(usdc));
        assertEq(address(vault.riskManager()), address(rm));
        assertEq(vault.decimals(), 12);
        assertEq(vault.name(), "Arcadia USDC Vault");
        assertEq(vault.symbol(), "aUSDC");
        assertEq(vault.totalAssets(), 0);
        assertEq(vault.sharePrice(), 1e6);
        assertTrue(vault.hasRole(DEFAULT_ADMIN_ROLE, admin));
        assertTrue(vault.hasRole(ADMIN_ROLE, admin));
        assertTrue(vault.hasRole(PAUSER_ROLE, admin));
    }

    function test_Constructor_ZeroAddressesRevert() public {
        vm.expectRevert(ArcadiaVault.ZeroAddress.selector);
        new ArcadiaVault(address(usdc), address(rm), address(0), "n", "s");
        vm.expectRevert(ArcadiaVault.ZeroAddress.selector);
        new ArcadiaVault(address(0), address(rm), admin, "n", "s");
        vm.expectRevert(ArcadiaVault.ZeroAddress.selector);
        new ArcadiaVault(address(usdc), address(0), admin, "n", "s");
    }

    function test_Constructor_InvalidContractAndDecimalsRevert() public {
        vm.expectRevert(ArcadiaVault.InvalidContract.selector);
        new ArcadiaVault(makeAddr("eoa"), address(rm), admin, "n", "s");
        vm.expectRevert(ArcadiaVault.InvalidContract.selector);
        new ArcadiaVault(address(usdc), makeAddr("eoa"), admin, "n", "s");
        MockDecimalsToken t18 = new MockDecimalsToken(18);
        vm.expectRevert(ArcadiaVault.InvalidAssetDecimals.selector);
        new ArcadiaVault(address(t18), address(rm), admin, "n", "s");
    }

    // ------------------------------------------------------------ deposit
    function test_Deposit_Valid() public {
        vm.expectEmit(true, true, false, true, address(vault));
        emit IERC4626.Deposit(alice, alice, 1000e6, 1000e6 * SCALE);
        uint256 shares = _vaultDeposit(alice, 1000e6);

        assertEq(shares, 1000e6 * SCALE);
        assertEq(vault.balanceOf(alice), shares);
        assertEq(vault.totalSupply(), shares);
        assertEq(vault.totalAssets(), 1000e6);
        assertEq(vault.accountedAssets(), 1000e6);
        assertEq(usdc.balanceOf(address(vault)), 1000e6);
        assertEq(vault.convertToAssets(shares), 1000e6);
        assertEq(vault.sharePrice(), 1e6);
    }

    function test_Deposit_ToDifferentReceiver() public {
        vm.prank(alice);
        vault.deposit(100e6, bob);
        assertEq(vault.balanceOf(bob), 100e6 * SCALE);
        assertEq(vault.balanceOf(alice), 0);
        assertEq(usdc.balanceOf(alice), 10_000_000e6 - 100e6);
    }

    function test_Deposit_ZeroAmountReverts() public {
        vm.prank(alice);
        vm.expectRevert(ArcadiaVault.ZeroAmount.selector);
        vault.deposit(0, alice);
    }

    function test_Deposit_WithoutAllowanceReverts() public {
        address dave = makeAddr("dave");
        usdc.mint(dave, 100e6);
        vm.prank(dave);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(vault), 0, 100e6));
        vault.deposit(100e6, dave);
        assertEq(vault.totalAssets(), 0);
        assertEq(vault.totalSupply(), 0);
    }

    function test_Deposit_ZeroReceiverReverts() public {
        vm.prank(alice);
        vm.expectRevert(); // OZ ERC20InvalidReceiver or ZeroAddress, either way blocked
        vault.deposit(1e6, address(0));
    }

    function test_Mint_Valid_And_Zero() public {
        vm.prank(alice);
        uint256 assets = vault.mint(5e6, alice); // 5e6 shares == 5 wei of USDC
        assertEq(assets, 5);
        assertEq(vault.balanceOf(alice), 5e6);
        assertEq(vault.totalAssets(), 5);

        vm.prank(alice);
        vm.expectRevert(ArcadiaVault.ZeroAmount.selector);
        vault.mint(0, alice);
    }

    // ------------------------------------------------------------ withdraw / redeem
    function test_Withdraw_Valid() public {
        _vaultDeposit(alice, 1000e6);
        uint256 before_ = usdc.balanceOf(alice);

        vm.expectEmit(true, true, true, true, address(vault));
        emit IERC4626.Withdraw(alice, alice, alice, 400e6, 400e6 * SCALE);
        vm.prank(alice);
        uint256 burned = vault.withdraw(400e6, alice, alice);

        assertEq(burned, 400e6 * SCALE);
        assertEq(usdc.balanceOf(alice), before_ + 400e6);
        assertEq(vault.totalAssets(), 600e6);
        assertEq(vault.balanceOf(alice), 600e6 * SCALE);
    }

    function test_Withdraw_ZeroReverts() public {
        _vaultDeposit(alice, 100e6);
        vm.prank(alice);
        vm.expectRevert(ArcadiaVault.ZeroAmount.selector);
        vault.withdraw(0, alice, alice);
    }

    function test_Withdraw_ExceedingBalanceReverts() public {
        _vaultDeposit(alice, 100e6);
        _vaultDeposit(bob, 1000e6);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC4626.ERC4626ExceededMaxWithdraw.selector, alice, 100e6 + 1, 100e6));
        vault.withdraw(100e6 + 1, alice, alice);
    }

    function test_Redeem_Valid_And_All() public {
        _vaultDeposit(alice, 1000e6);
        vm.prank(alice);
        uint256 out = vault.redeem(250e6 * SCALE, alice, alice);
        assertEq(out, 250e6);
        assertEq(vault.maxRedeem(alice), 750e6 * SCALE);
        uint256 rest = vault.balanceOf(alice);
        vm.prank(alice);
        out = vault.redeem(rest, alice, alice);
        assertEq(out, 750e6);
        assertEq(vault.totalSupply(), 0);
        assertEq(vault.totalAssets(), 0);
        assertEq(usdc.balanceOf(address(vault)), 0);
    }

    function test_Redeem_ExceedingSharesReverts() public {
        _vaultDeposit(alice, 100e6);
        vm.prank(alice);
        vm.expectRevert();
        vault.redeem(100e6 * SCALE + 1, alice, alice);
    }

    function test_Withdraw_ByThirdParty_NeedsAllowance() public {
        _vaultDeposit(alice, 100e6);
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, bob, 0, 50e6 * SCALE));
        vault.withdraw(50e6, bob, alice);

        vm.prank(alice);
        vault.approve(bob, 50e6 * SCALE);
        vm.prank(bob);
        vault.withdraw(50e6, bob, alice);
        assertEq(usdc.balanceOf(bob), 10_000_000e6 + 50e6);
        assertEq(vault.allowance(alice, bob), 0);
    }

    function test_MultiUser_DepositsAndWithdrawals() public {
        _vaultDeposit(alice, 1000e6);
        _vaultDeposit(bob, 2500e6);
        _vaultDeposit(carol, 500e6);
        assertEq(vault.totalAssets(), 4000e6);

        vm.prank(alice);
        vault.withdraw(400e6, alice, alice);
        uint256 bobShares = vault.balanceOf(bob);
        vm.prank(bob);
        vault.redeem(bobShares, bob, bob);
        _vaultDeposit(carol, 250e6);

        assertEq(vault.convertToAssets(vault.balanceOf(alice)), 600e6);
        assertEq(vault.balanceOf(bob), 0);
        assertEq(vault.convertToAssets(vault.balanceOf(carol)), 750e6);
        assertEq(vault.totalAssets(), 1350e6);
        assertEq(usdc.balanceOf(address(vault)), 1350e6);
        assertEq(vault.sharePrice(), 1e6);
    }

    // ------------------------------------------------------------ pause
    function test_LocalPause_BlocksDepositAndMint_NotWithdraw() public {
        _vaultDeposit(alice, 1000e6);
        vm.expectEmit(true, false, false, true, address(vault));
        emit ArcadiaVault.VaultPaused(admin, true);
        vm.prank(admin);
        vault.pause();
        assertTrue(vault.paused());
        assertEq(vault.maxDeposit(bob), 0);
        assertEq(vault.maxMint(bob), 0);

        vm.prank(bob);
        vm.expectRevert(); // ERC4626ExceededMaxDeposit (max == 0)
        vault.deposit(1e6, bob);
        vm.prank(bob);
        vm.expectRevert(); // ERC4626ExceededMaxMint
        vault.mint(1e6, bob);

        vm.prank(alice);
        vault.withdraw(100e6, alice, alice);
        uint256 aliceShares = vault.balanceOf(alice);
        vm.prank(alice);
        vault.redeem(aliceShares, alice, alice);
        assertEq(vault.totalAssets(), 0);

        vm.expectEmit(true, false, false, true, address(vault));
        emit ArcadiaVault.VaultPaused(admin, false);
        vm.prank(admin);
        vault.unpause();
        _vaultDeposit(bob, 1e6);
        assertEq(vault.balanceOf(bob), 1e6 * SCALE);
    }

    function test_Pause_DoubleReverts() public {
        vm.startPrank(admin);
        vault.pause();
        vm.expectRevert(Pausable.EnforcedPause.selector);
        vault.pause();
        vault.unpause();
        vm.expectRevert(Pausable.ExpectedPause.selector);
        vault.unpause();
        vm.stopPrank();
    }

    function test_ProtocolPaused_BlocksDepositAndWithdraw() public {
        _vaultDeposit(alice, 1000e6);
        vm.prank(admin);
        rm.pauseProtocol();
        assertEq(vault.maxDeposit(alice), 0);
        assertEq(vault.maxWithdraw(alice), 0);
        assertEq(vault.maxRedeem(alice), 0);

        vm.prank(bob);
        vm.expectRevert();
        vault.deposit(1e6, bob);
        vm.prank(alice);
        vm.expectRevert();
        vault.withdraw(1e6, alice, alice);
        vm.prank(alice);
        vm.expectRevert();
        vault.redeem(1e6 * SCALE, alice, alice);

        vm.prank(admin);
        rm.unpauseProtocol();
        vm.prank(alice);
        vault.withdraw(1e6, alice, alice);
    }

    function test_WithdrawalsPaused_BlocksWithdraw_NotDeposit() public {
        _vaultDeposit(alice, 1000e6);
        vm.prank(admin);
        rm.setWithdrawalsPaused(address(vault), true);
        assertEq(vault.maxWithdraw(alice), 0);
        assertEq(vault.maxRedeem(alice), 0);

        vm.prank(alice);
        vm.expectRevert();
        vault.withdraw(1e6, alice, alice);
        vm.prank(alice);
        vm.expectRevert();
        vault.redeem(1e6 * SCALE, alice, alice);

        _vaultDeposit(bob, 10e6); // deposits still work
        assertEq(vault.totalAssets(), 1010e6);

        vm.prank(admin);
        rm.setWithdrawalsPaused(address(vault), false);
        vm.prank(alice);
        vault.withdraw(1e6, alice, alice);
    }

    // ------------------------------------------------------------ risk limits
    function test_DepositCap_Enforced() public {
        vm.prank(admin);
        rm.setDefaults(100e6, 100e6, 1, 0);
        _vaultDeposit(alice, 60e6);
        assertEq(vault.maxDeposit(bob), 40e6);
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(ERC4626.ERC4626ExceededMaxDeposit.selector, bob, 41e6, 40e6));
        vault.deposit(41e6, bob);
        _vaultDeposit(bob, 40e6);
        assertEq(vault.maxDeposit(carol), 0);
        assertEq(vault.totalAssets(), 100e6);
    }

    function test_MinDeposit_Enforced() public {
        vm.prank(admin);
        rm.setDefaults(CAP, MAX_DEP, 10e6, 0);
        vm.prank(alice);
        vm.expectRevert(RiskManager.BelowMinDeposit.selector);
        vault.deposit(10e6 - 1, alice);
        _vaultDeposit(alice, 10e6);
    }

    function test_MaxDepositPerTx_Enforced() public {
        assertEq(vault.maxDeposit(alice), MAX_DEP);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC4626.ERC4626ExceededMaxDeposit.selector, alice, MAX_DEP + 1, MAX_DEP));
        vault.deposit(MAX_DEP + 1, alice);
        _vaultDeposit(alice, MAX_DEP);
    }

    function test_MaxWithdrawPerTx_Enforced() public {
        _vaultDeposit(alice, 1000e6);
        vm.prank(admin);
        rm.setDefaults(CAP, MAX_DEP, MIN_DEP, 100e6);
        assertEq(vault.maxWithdraw(alice), 100e6);
        assertEq(vault.maxRedeem(alice), 100e6 * SCALE);
        vm.prank(alice);
        vm.expectRevert();
        vault.withdraw(100e6 + 1, alice, alice);
        vm.prank(alice);
        vault.withdraw(100e6, alice, alice);
    }

    function test_MaxDeposit_ZeroReceiver_IsZero() public view {
        assertEq(vault.maxDeposit(address(0)), 0);
    }

    // ------------------------------------------------------------ access control
    function test_Unauthorized_Pause() public {
        vm.prank(stranger);
        _expectUnauth(stranger, PAUSER_ROLE);
        vault.pause();
    }

    function test_Unauthorized_Unpause() public {
        vm.prank(admin);
        vault.pause();
        vm.prank(stranger);
        _expectUnauth(stranger, PAUSER_ROLE);
        vault.unpause();
    }

    function test_Unauthorized_SweepUnaccounted() public {
        vm.prank(stranger);
        _expectUnauth(stranger, ADMIN_ROLE);
        vault.sweepUnaccounted(stranger);
    }
}
