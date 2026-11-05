// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ArcadiaBase} from "./Arcadia.Base.t.sol";
import {LendingPool} from "../LendingPool.sol";
import {RiskManager} from "../RiskManager.sol";
import {ILendingPool} from "../interfaces/ILendingPool.sol";
import {MockDecimalsToken} from "./MockUSDC.sol";

contract LendingPoolTest is ArcadiaBase {
    uint256 internal constant SCALE = 1e6; // VIRTUAL_SHARES: shares minted per asset base unit when price == 1

    // ------------------------------------------------------------ constructor
    function test_Constructor_WiresStateAndRoles() public view {
        assertEq(address(pool.asset()), address(usdc));
        assertEq(address(pool.riskManager()), address(rm));
        assertEq(address(pool.interestRateModel()), address(irm));
        assertEq(pool.reserveFactorWad(), RF);
        assertEq(pool.lastAccrual(), block.timestamp);
        assertTrue(pool.hasRole(DEFAULT_ADMIN_ROLE, admin));
        assertTrue(pool.hasRole(ADMIN_ROLE, admin));
        assertTrue(pool.hasRole(PAUSER_ROLE, admin));
        assertFalse(pool.paused());
    }

    function test_Constructor_ZeroAddressesRevert() public {
        vm.expectRevert(LendingPool.ZeroAddress.selector);
        new LendingPool(address(usdc), address(rm), address(irm), address(0), RF);
        vm.expectRevert(LendingPool.ZeroAddress.selector);
        new LendingPool(address(0), address(rm), address(irm), admin, RF);
        vm.expectRevert(LendingPool.ZeroAddress.selector);
        new LendingPool(address(usdc), address(0), address(irm), admin, RF);
        vm.expectRevert(LendingPool.ZeroAddress.selector);
        new LendingPool(address(usdc), address(rm), address(0), admin, RF);
    }

    function test_Constructor_EoaDependenciesRevert() public {
        vm.expectRevert(LendingPool.InvalidContract.selector);
        new LendingPool(makeAddr("eoa"), address(rm), address(irm), admin, RF);
        vm.expectRevert(LendingPool.InvalidContract.selector);
        new LendingPool(address(usdc), makeAddr("eoa"), address(irm), admin, RF);
        vm.expectRevert(LendingPool.InvalidContract.selector);
        new LendingPool(address(usdc), address(rm), makeAddr("eoa"), admin, RF);
    }

    function test_Constructor_WrongDecimalsReverts() public {
        MockDecimalsToken t18 = new MockDecimalsToken(18);
        vm.expectRevert(LendingPool.InvalidAssetDecimals.selector);
        new LendingPool(address(t18), address(rm), address(irm), admin, RF);
    }

    function test_Constructor_ReserveFactorBounds() public {
        vm.expectRevert(LendingPool.InvalidReserveFactor.selector);
        new LendingPool(address(usdc), address(rm), address(irm), admin, 0.5e18 + 1);
        LendingPool p = new LendingPool(address(usdc), address(rm), address(irm), admin, 0.5e18);
        assertEq(p.reserveFactorWad(), 0.5e18);
        p = new LendingPool(address(usdc), address(rm), address(irm), admin, 0);
        assertEq(p.reserveFactorWad(), 0);
    }

    // ------------------------------------------------------------ supply
    function test_Supply_Valid() public {
        vm.expectEmit(true, true, false, true, address(pool));
        emit LendingPool.Supply(alice, alice, 1000e6, 1000e6 * SCALE);
        uint256 shares = _supply(alice, 1000e6);

        assertEq(shares, 1000e6 * SCALE);
        assertEq(pool.supplyShares(alice), shares);
        assertEq(pool.totalSupplyShares(), shares);
        assertEq(pool.totalSupplied(), 1000e6);
        assertEq(pool.balanceOf(alice), 1000e6);
        assertEq(usdc.balanceOf(address(pool)), 1000e6);
        assertEq(usdc.balanceOf(alice), 10_000_000e6 - 1000e6);
        assertEq(pool.availableLiquidity(), 1000e6);
    }

    function test_Supply_ZeroAmountReverts() public {
        vm.prank(alice);
        vm.expectRevert(LendingPool.ZeroAmount.selector);
        pool.supply(0);
    }

    function test_Supply_WithoutAllowanceReverts() public {
        address dave = makeAddr("dave");
        usdc.mint(dave, 100e6);
        vm.prank(dave);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(pool), 0, 100e6));
        pool.supply(100e6);
        assertEq(pool.totalSupplied(), 0);
    }

    function test_Supply_WithoutBalanceReverts() public {
        address dave = makeAddr("dave");
        vm.startPrank(dave);
        usdc.approve(address(pool), type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, dave, 0, 100e6));
        pool.supply(100e6);
        vm.stopPrank();
    }

    function test_SupplyFor_CreditsBeneficiary_PullsFromCaller() public {
        vm.expectEmit(true, true, false, true, address(pool));
        emit LendingPool.Supply(bob, carol, 500e6, 500e6 * SCALE);
        vm.prank(bob);
        pool.supplyFor(carol, 500e6);
        assertEq(pool.balanceOf(carol), 500e6);
        assertEq(pool.balanceOf(bob), 0);
        assertEq(usdc.balanceOf(bob), 10_000_000e6 - 500e6);
    }

    function test_SupplyFor_ZeroBeneficiaryReverts() public {
        vm.prank(bob);
        vm.expectRevert(LendingPool.ZeroAddress.selector);
        pool.supplyFor(address(0), 1e6);
    }

    function test_SupplyFor_ZeroAmountReverts() public {
        vm.prank(bob);
        vm.expectRevert(LendingPool.ZeroAmount.selector);
        pool.supplyFor(carol, 0);
    }

    // ------------------------------------------------------------ withdraw
    function test_Withdraw_Valid() public {
        _supply(alice, 1000e6);
        uint256 before_ = usdc.balanceOf(alice);

        vm.expectEmit(true, false, false, true, address(pool));
        emit LendingPool.Withdraw(alice, 400e6, 400e6 * SCALE);
        vm.prank(alice);
        uint256 shares = pool.withdraw(400e6);

        assertEq(shares, 400e6 * SCALE);
        assertEq(usdc.balanceOf(alice), before_ + 400e6);
        assertEq(pool.balanceOf(alice), 600e6);
        assertEq(pool.totalSupplied(), 600e6);
        assertEq(pool.supplyShares(alice), 600e6 * SCALE);
        assertEq(usdc.balanceOf(address(pool)), 600e6);
    }

    function test_Withdraw_ZeroReverts() public {
        _supply(alice, 100e6);
        vm.prank(alice);
        vm.expectRevert(LendingPool.ZeroAmount.selector);
        pool.withdraw(0);
    }

    function test_Withdraw_ExceedingBalanceReverts() public {
        // plenty of pool liquidity from bob, so it is alice's own balance that binds
        _supply(alice, 100e6);
        _supply(bob, 1000e6);
        vm.prank(alice);
        vm.expectRevert(LendingPool.InsufficientLiquidity.selector);
        pool.withdraw(100e6 + 1);
        // bob's funds untouched
        assertEq(pool.balanceOf(bob), 1000e6);
    }

    function test_Withdraw_WithNoSharesReverts() public {
        _supply(bob, 1000e6);
        vm.prank(alice);
        vm.expectRevert(LendingPool.InsufficientLiquidity.selector);
        pool.withdraw(1);
    }

    function test_Withdraw_ExceedingAvailableLiquidityReverts() public {
        _supply(alice, 1000e6);
        _borrow(600e6);
        assertEq(pool.availableLiquidity(), 400e6);

        vm.prank(alice);
        vm.expectRevert(LendingPool.InsufficientLiquidity.selector);
        pool.withdraw(400e6 + 1);

        vm.prank(alice);
        pool.withdraw(400e6); // exactly the liquidity works
        assertEq(pool.availableLiquidity(), 0);
        assertEq(usdc.balanceOf(address(pool)), 0);

        // after repay, rest is withdrawable
        vm.prank(borrower);
        usdc.approve(address(pool), type(uint256).max);
        pool.repayFrom(borrower, 600e6);
        vm.prank(alice);
        pool.withdraw(600e6);
        assertEq(pool.totalSupplied(), 0);
    }

    function test_WithdrawAll_Valid() public {
        _supply(alice, 1234_567_891);
        vm.expectEmit(true, false, false, true, address(pool));
        emit LendingPool.Withdraw(alice, 1234_567_891, 1234_567_891 * SCALE);
        vm.prank(alice);
        uint256 out = pool.withdrawAll();
        assertEq(out, 1234_567_891);
        assertEq(pool.supplyShares(alice), 0);
        assertEq(pool.totalSupplyShares(), 0);
        assertEq(pool.totalSupplied(), 0);
        assertEq(usdc.balanceOf(address(pool)), 0);
    }

    function test_WithdrawAll_NoSharesReverts() public {
        vm.prank(alice);
        vm.expectRevert(LendingPool.ZeroAmount.selector);
        pool.withdrawAll();
    }

    function test_WithdrawAll_LimitedByLiquidity() public {
        _supply(alice, 1000e6);
        _borrow(1);
        vm.prank(alice);
        vm.expectRevert(LendingPool.InsufficientLiquidity.selector);
        pool.withdrawAll();
    }

    // ------------------------------------------------------------ multi-user
    function test_MultiUser_DepositsAndWithdrawals() public {
        _supply(alice, 1000e6);
        _supply(bob, 2500e6);
        _supply(carol, 500e6);
        assertEq(pool.totalSupplied(), 4000e6);
        assertEq(pool.balanceOf(alice), 1000e6);
        assertEq(pool.balanceOf(bob), 2500e6);
        assertEq(pool.balanceOf(carol), 500e6);

        vm.prank(alice);
        pool.withdraw(400e6);
        vm.prank(bob);
        pool.withdrawAll();
        _supply(carol, 250e6);
        _supply(alice, 100e6);

        assertEq(pool.balanceOf(alice), 700e6);
        assertEq(pool.balanceOf(bob), 0);
        assertEq(pool.balanceOf(carol), 750e6);
        assertEq(pool.totalSupplied(), 1450e6);
        assertEq(usdc.balanceOf(address(pool)), 1450e6);
        assertEq(pool.totalSupplyShares(), 1450e6 * SCALE);
        assertEq(
            pool.supplyShares(alice) + pool.supplyShares(bob) + pool.supplyShares(carol), pool.totalSupplyShares()
        );
    }

    function test_SharePrice_StaysOne_AcrossDepositsAndDonations() public {
        _supply(alice, 1000e6);
        _donate(address(pool), 777e6);
        assertEq(pool.balanceOf(alice), 1000e6);
        assertEq(pool.totalSupplied(), 1000e6);

        uint256 bobShares = _supply(bob, 1000e6);
        assertEq(bobShares, 1000e6 * SCALE, "donation must not dilute newcomers");
        assertEq(pool.balanceOf(bob), 1000e6);
        assertEq(pool.balanceOf(alice), 1000e6);
        // preview functions agree
        assertEq(pool.previewSupply(10e6), 10e6 * SCALE);
        assertEq(pool.previewWithdraw(10e6), 10e6 * SCALE);
        assertEq(pool.previewRedeem(10e6 * SCALE), 10e6);
    }

    // ------------------------------------------------------------ pause
    function test_LocalPause_BlocksSupply_NotWithdraw() public {
        _supply(alice, 1000e6);
        vm.prank(admin);
        pool.pause();
        assertTrue(pool.paused());

        vm.prank(bob);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        pool.supply(1e6);
        vm.prank(bob);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        pool.supplyFor(carol, 1e6);

        vm.prank(alice);
        pool.withdraw(100e6);
        vm.prank(alice);
        pool.withdrawAll();
        assertEq(pool.totalSupplied(), 0);

        vm.prank(admin);
        pool.unpause();
        _supply(bob, 1e6);
        assertEq(pool.balanceOf(bob), 1e6);
    }

    function test_Pause_DoubleReverts() public {
        vm.startPrank(admin);
        pool.pause();
        vm.expectRevert(Pausable.EnforcedPause.selector);
        pool.pause();
        pool.unpause();
        vm.expectRevert(Pausable.ExpectedPause.selector);
        pool.unpause();
        vm.stopPrank();
    }

    function test_ProtocolPaused_BlocksSupplyAndWithdraw() public {
        _supply(alice, 1000e6);
        vm.prank(admin);
        rm.pauseProtocol();

        vm.prank(bob);
        vm.expectRevert(RiskManager.ProtocolPaused.selector);
        pool.supply(1e6);
        vm.prank(alice);
        vm.expectRevert(RiskManager.ProtocolPaused.selector);
        pool.withdraw(1e6);
        vm.prank(alice);
        vm.expectRevert(RiskManager.ProtocolPaused.selector);
        pool.withdrawAll();

        vm.prank(admin);
        rm.unpauseProtocol();
        vm.prank(alice);
        pool.withdraw(1e6);
    }

    function test_WithdrawalsPaused_BlocksWithdraw_NotSupply() public {
        _supply(alice, 1000e6);
        vm.prank(admin);
        rm.setWithdrawalsPaused(address(pool), true);

        vm.prank(alice);
        vm.expectRevert(RiskManager.WithdrawalsPaused.selector);
        pool.withdraw(1e6);
        vm.prank(alice);
        vm.expectRevert(RiskManager.WithdrawalsPaused.selector);
        pool.withdrawAll();

        _supply(bob, 10e6); // supply still allowed
        assertEq(pool.balanceOf(bob), 10e6);

        vm.prank(admin);
        rm.setWithdrawalsPaused(address(pool), false);
        vm.prank(alice);
        pool.withdraw(1e6);
    }

    // ------------------------------------------------------------ risk limits
    function test_DepositCap_Enforced() public {
        // cap 5M, per-tx 1M
        for (uint256 i; i < 5; i++) {
            _supply(i % 2 == 0 ? alice : bob, 1_000_000e6);
        }
        assertEq(pool.totalSupplied(), CAP);
        vm.prank(carol);
        vm.expectRevert(RiskManager.DepositCapExceeded.selector);
        pool.supply(1);
        // free headroom by withdrawing then fill exactly
        vm.prank(alice);
        pool.withdraw(10e6);
        _supply(carol, 10e6);
        assertEq(pool.totalSupplied(), CAP);
    }

    function test_DonationDoesNotCountTowardsCap() public {
        _donate(address(pool), CAP * 2);
        _supply(alice, 1_000_000e6);
        assertEq(pool.totalSupplied(), 1_000_000e6);
    }

    function test_MinDeposit_Enforced() public {
        vm.prank(admin);
        rm.setDefaults(CAP, MAX_DEP, 10e6, 0);
        vm.prank(alice);
        vm.expectRevert(RiskManager.BelowMinDeposit.selector);
        pool.supply(10e6 - 1);
        _supply(alice, 10e6);
        assertEq(pool.balanceOf(alice), 10e6);
    }

    function test_MaxDepositPerTx_Enforced() public {
        vm.prank(alice);
        vm.expectRevert(RiskManager.AboveMaxDepositPerTx.selector);
        pool.supply(MAX_DEP + 1);
        _supply(alice, MAX_DEP);
    }

    function test_MaxWithdrawPerTx_Enforced() public {
        _supply(alice, 1000e6);
        vm.prank(admin);
        rm.setDefaults(CAP, MAX_DEP, MIN_DEP, 100e6);
        vm.prank(alice);
        vm.expectRevert(RiskManager.AboveMaxWithdrawPerTx.selector);
        pool.withdraw(100e6 + 1);
        vm.prank(alice);
        vm.expectRevert(RiskManager.AboveMaxWithdrawPerTx.selector);
        pool.withdrawAll();
        vm.prank(alice);
        pool.withdraw(100e6);
        assertEq(pool.balanceOf(alice), 900e6);
    }

    function test_MarketOverride_AppliesToPool() public {
        vm.prank(admin);
        rm.setMarketRisk(address(pool), 50e6, 20e6, 5e6, 0);
        vm.prank(alice);
        vm.expectRevert(RiskManager.AboveMaxDepositPerTx.selector);
        pool.supply(20e6 + 1);
        _supply(alice, 20e6);
        _supply(alice, 20e6);
        _supply(alice, 10e6);
        vm.prank(alice);
        vm.expectRevert(RiskManager.DepositCapExceeded.selector);
        pool.supply(5e6);
    }

    // ------------------------------------------------------------ access control
    function test_Unauthorized_Pause() public {
        vm.prank(stranger);
        _expectUnauth(stranger, PAUSER_ROLE);
        pool.pause();
    }

    function test_Unauthorized_Unpause() public {
        vm.prank(admin);
        pool.pause();
        vm.prank(stranger);
        _expectUnauth(stranger, PAUSER_ROLE);
        pool.unpause();
    }

    function test_Unauthorized_WithdrawReserves() public {
        vm.prank(stranger);
        _expectUnauth(stranger, ADMIN_ROLE);
        pool.withdrawReserves(stranger, 1);
    }

    function test_Unauthorized_SweepUnaccounted() public {
        vm.prank(stranger);
        _expectUnauth(stranger, ADMIN_ROLE);
        pool.sweepUnaccounted(stranger);
    }

    function test_Unauthorized_AccrueIsPermissionless() public {
        vm.prank(stranger);
        pool.accrueInterest(); // must not revert
    }

    function test_PauserRole_SeparateFromAdminRole() public {
        vm.prank(admin);
        pool.grantRole(PAUSER_ROLE, alice);
        vm.prank(alice);
        pool.pause();
        vm.prank(alice);
        _expectUnauth(alice, ADMIN_ROLE);
        pool.sweepUnaccounted(alice);
    }

    // ------------------------------------------------------------ views
    function test_GetMarketState_Fresh() public {
        _supply(alice, 1000e6);
        ILendingPool.MarketState memory s = pool.getMarketState();
        assertEq(s.supplied, 1000e6);
        assertEq(s.borrowed, 0);
        assertEq(s.reserves, 0);
        assertEq(s.shares, 1000e6 * SCALE);
        assertEq(s.liquidity, 1000e6);
        assertEq(s.utilizationWad, 0);
        assertEq(s.borrowRateWad, BASE);
        assertEq(s.supplyRateWad, 0);
        assertEq(s.lastAccrual, block.timestamp);
        assertEq(pool.utilization(), 0);
        assertEq(pool.borrowRate(), BASE);
        assertEq(pool.supplyRate(), 0);
    }
}
