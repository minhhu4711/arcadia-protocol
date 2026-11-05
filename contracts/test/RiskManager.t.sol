// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ArcadiaBase} from "./Arcadia.Base.t.sol";
import {RiskManager} from "../RiskManager.sol";
import {IRiskManager} from "../interfaces/IRiskManager.sol";

contract RiskManagerTest is ArcadiaBase {
    address internal market = makeAddr("market");

    // ------------------------------------------------------------ constructor
    function test_Constructor_SetsDefaultsAndRoles() public view {
        assertEq(rm.defaultDepositCap(), CAP);
        assertEq(rm.defaultMaxDepositPerTx(), MAX_DEP);
        assertEq(rm.defaultMinDeposit(), MIN_DEP);
        assertEq(rm.defaultMaxWithdrawPerTx(), MAX_WD);
        assertFalse(rm.protocolPaused());
        assertTrue(rm.hasRole(DEFAULT_ADMIN_ROLE, admin));
        assertTrue(rm.hasRole(RISK_ADMIN_ROLE, admin));
        assertTrue(rm.hasRole(PAUSER_ROLE, admin));
        assertFalse(rm.hasRole(RISK_ADMIN_ROLE, address(this)));
    }

    function test_Constructor_ZeroAdminReverts() public {
        vm.expectRevert(RiskManager.ZeroAddress.selector);
        new RiskManager(address(0), CAP, MAX_DEP, MIN_DEP, MAX_WD);
    }

    function test_Constructor_InvalidParamsRevert() public {
        vm.expectRevert(RiskManager.InvalidRiskParameters.selector);
        new RiskManager(admin, 0, 0, 0, 0); // cap == 0
        vm.expectRevert(RiskManager.InvalidRiskParameters.selector);
        new RiskManager(admin, CAP, MAX_DEP, MAX_DEP + 1, 0); // min > max
        vm.expectRevert(RiskManager.InvalidRiskParameters.selector);
        new RiskManager(admin, CAP, CAP + 1, 1, 0); // max > cap
    }

    function test_Constructor_AllowsEdgeParams() public {
        RiskManager r = new RiskManager(admin, 10, 10, 10, 0);
        assertEq(r.defaultDepositCap(), 10);
        assertEq(r.defaultMinDeposit(), 10);
    }

    // ------------------------------------------------------------ pause
    function test_PauseProtocol_Works_And_Emits() public {
        vm.expectEmit(false, false, false, true, address(rm));
        emit RiskManager.ProtocolPauseChanged(true);
        vm.prank(admin);
        rm.pauseProtocol();
        assertTrue(rm.protocolPaused());

        vm.expectEmit(false, false, false, true, address(rm));
        emit RiskManager.ProtocolPauseChanged(false);
        vm.prank(admin);
        rm.unpauseProtocol();
        assertFalse(rm.protocolPaused());
    }

    function test_SetWithdrawalsPaused_Works_And_Emits() public {
        vm.expectEmit(true, false, false, true, address(rm));
        emit RiskManager.WithdrawalsPauseChanged(market, true);
        vm.prank(admin);
        rm.setWithdrawalsPaused(market, true);
        assertTrue(rm.getRisk(market).withdrawalsPaused);
        // not configured => defaults still apply
        assertFalse(rm.getRisk(market).configured);
        assertEq(rm.getRisk(market).depositCap, CAP);

        vm.prank(admin);
        rm.setWithdrawalsPaused(market, false);
        assertFalse(rm.getRisk(market).withdrawalsPaused);
    }

    function test_SetWithdrawalsPaused_ZeroMarketReverts() public {
        vm.prank(admin);
        vm.expectRevert(RiskManager.ZeroAddress.selector);
        rm.setWithdrawalsPaused(address(0), true);
    }

    // ------------------------------------------------------------ access control
    function test_Unauthorized_PauseProtocol() public {
        vm.prank(stranger);
        _expectUnauth(stranger, PAUSER_ROLE);
        rm.pauseProtocol();
    }

    function test_Unauthorized_UnpauseProtocol() public {
        vm.prank(stranger);
        _expectUnauth(stranger, PAUSER_ROLE);
        rm.unpauseProtocol();
    }

    function test_Unauthorized_SetWithdrawalsPaused() public {
        vm.prank(stranger);
        _expectUnauth(stranger, PAUSER_ROLE);
        rm.setWithdrawalsPaused(market, true);
    }

    function test_Unauthorized_SetDefaults() public {
        vm.prank(stranger);
        _expectUnauth(stranger, RISK_ADMIN_ROLE);
        rm.setDefaults(CAP, MAX_DEP, MIN_DEP, 0);
    }

    function test_Unauthorized_SetMarketRisk() public {
        vm.prank(stranger);
        _expectUnauth(stranger, RISK_ADMIN_ROLE);
        rm.setMarketRisk(market, CAP, MAX_DEP, MIN_DEP, 0);
    }

    function test_Unauthorized_ClearMarketRisk() public {
        vm.prank(stranger);
        _expectUnauth(stranger, RISK_ADMIN_ROLE);
        rm.clearMarketRisk(market);
    }

    function test_RoleSeparation_PauserCannotSetRisk_RiskAdminCannotPause() public {
        vm.startPrank(admin);
        rm.grantRole(PAUSER_ROLE, alice);
        rm.grantRole(RISK_ADMIN_ROLE, bob);
        vm.stopPrank();

        vm.prank(alice);
        _expectUnauth(alice, RISK_ADMIN_ROLE);
        rm.setDefaults(CAP, MAX_DEP, MIN_DEP, 0);

        vm.prank(bob);
        _expectUnauth(bob, PAUSER_ROLE);
        rm.pauseProtocol();

        vm.prank(alice);
        rm.pauseProtocol();
        assertTrue(rm.protocolPaused());
    }

    // ------------------------------------------------------------ setDefaults
    function test_SetDefaults_UpdatesAndEmits() public {
        vm.expectEmit(false, false, false, true, address(rm));
        emit RiskManager.DefaultsUpdated(200e6, 100e6, 5e6, 50e6);
        vm.prank(admin);
        rm.setDefaults(200e6, 100e6, 5e6, 50e6);
        assertEq(rm.defaultDepositCap(), 200e6);
        assertEq(rm.defaultMaxDepositPerTx(), 100e6);
        assertEq(rm.defaultMinDeposit(), 5e6);
        assertEq(rm.defaultMaxWithdrawPerTx(), 50e6);
    }

    function test_SetDefaults_InvalidReverts() public {
        vm.startPrank(admin);
        vm.expectRevert(RiskManager.InvalidRiskParameters.selector);
        rm.setDefaults(0, 0, 0, 0);
        vm.expectRevert(RiskManager.InvalidRiskParameters.selector);
        rm.setDefaults(100, 50, 51, 0);
        vm.expectRevert(RiskManager.InvalidRiskParameters.selector);
        rm.setDefaults(100, 101, 1, 0);
        vm.stopPrank();
    }

    // ------------------------------------------------------------ market overrides
    function test_SetMarketRisk_OverridesDefaults_AndEmits() public {
        vm.expectEmit(true, false, false, true, address(rm));
        emit RiskManager.MarketRiskUpdated(market, 100e6, 40e6, 2e6, 10e6);
        vm.prank(admin);
        rm.setMarketRisk(market, 100e6, 40e6, 2e6, 10e6);

        IRiskManager.MarketRisk memory r = rm.getRisk(market);
        assertTrue(r.configured);
        assertEq(r.depositCap, 100e6);
        assertEq(r.maxDepositPerTx, 40e6);
        assertEq(r.minDeposit, 2e6);
        assertEq(r.maxWithdrawPerTx, 10e6);
        // other markets keep defaults
        assertEq(rm.getRisk(address(pool)).depositCap, CAP);
    }

    function test_SetMarketRisk_InvalidAndZeroReverts() public {
        vm.startPrank(admin);
        vm.expectRevert(RiskManager.ZeroAddress.selector);
        rm.setMarketRisk(address(0), CAP, MAX_DEP, MIN_DEP, 0);
        vm.expectRevert(RiskManager.InvalidRiskParameters.selector);
        rm.setMarketRisk(market, 0, 0, 0, 0);
        vm.expectRevert(RiskManager.InvalidRiskParameters.selector);
        rm.setMarketRisk(market, 100, 100, 101, 0);
        vm.expectRevert(RiskManager.InvalidRiskParameters.selector);
        rm.setMarketRisk(market, 100, 101, 1, 0);
        vm.stopPrank();
    }

    function test_SetMarketRisk_PreservesWithdrawalPause() public {
        vm.startPrank(admin);
        rm.setWithdrawalsPaused(market, true);
        rm.setMarketRisk(market, 100e6, 40e6, 2e6, 0);
        vm.stopPrank();
        assertTrue(rm.getRisk(market).withdrawalsPaused);
    }

    function test_ClearMarketRisk_RestoresDefaults_KeepsPause_AndEmits() public {
        vm.startPrank(admin);
        rm.setMarketRisk(market, 100e6, 40e6, 2e6, 10e6);
        rm.setWithdrawalsPaused(market, true);
        vm.expectEmit(true, false, false, false, address(rm));
        emit RiskManager.MarketRiskCleared(market);
        rm.clearMarketRisk(market);
        vm.stopPrank();

        IRiskManager.MarketRisk memory r = rm.getRisk(market);
        assertFalse(r.configured);
        assertEq(r.depositCap, CAP);
        assertEq(r.maxDepositPerTx, MAX_DEP);
        assertTrue(r.withdrawalsPaused);
    }

    function test_ClearMarketRisk_ZeroReverts() public {
        vm.prank(admin);
        vm.expectRevert(RiskManager.ZeroAddress.selector);
        rm.clearMarketRisk(address(0));
    }

    // ------------------------------------------------------------ validateDeposit
    function test_ValidateDeposit_Boundaries_Pass() public {
        vm.prank(admin);
        rm.setDefaults(100e6, 60e6, 5e6, 0);
        rm.validateDeposit(market, 5e6, 5e6); // == min
        rm.validateDeposit(market, 60e6, 60e6); // == max per tx
        rm.validateDeposit(market, 10e6, 100e6); // == cap
    }

    function test_ValidateDeposit_Reverts() public {
        vm.prank(admin);
        rm.setDefaults(100e6, 60e6, 5e6, 0);
        vm.expectRevert(RiskManager.BelowMinDeposit.selector);
        rm.validateDeposit(market, 5e6 - 1, 5e6);
        vm.expectRevert(RiskManager.AboveMaxDepositPerTx.selector);
        rm.validateDeposit(market, 60e6 + 1, 61e6);
        vm.expectRevert(RiskManager.DepositCapExceeded.selector);
        rm.validateDeposit(market, 10e6, 100e6 + 1);
    }

    function test_ValidateDeposit_ProtocolPausedReverts() public {
        vm.prank(admin);
        rm.pauseProtocol();
        vm.expectRevert(RiskManager.ProtocolPaused.selector);
        rm.validateDeposit(market, 1e6, 1e6);
    }

    // ------------------------------------------------------------ validateWithdraw
    function test_ValidateWithdraw_Paths() public {
        // unlimited by default
        rm.validateWithdraw(market, type(uint256).max);

        vm.startPrank(admin);
        rm.setDefaults(CAP, MAX_DEP, MIN_DEP, 50e6);
        vm.stopPrank();
        rm.validateWithdraw(market, 50e6);
        vm.expectRevert(RiskManager.AboveMaxWithdrawPerTx.selector);
        rm.validateWithdraw(market, 50e6 + 1);

        vm.prank(admin);
        rm.setWithdrawalsPaused(market, true);
        vm.expectRevert(RiskManager.WithdrawalsPaused.selector);
        rm.validateWithdraw(market, 1);

        vm.prank(admin);
        rm.pauseProtocol();
        vm.expectRevert(RiskManager.ProtocolPaused.selector);
        rm.validateWithdraw(address(pool), 1);
    }

    // ------------------------------------------------------------ maxDepositFor
    function test_MaxDepositFor() public {
        vm.prank(admin);
        rm.setDefaults(100e6, 60e6, 5e6, 0);
        assertEq(rm.maxDepositFor(market, 0), 60e6); // per-tx binds
        assertEq(rm.maxDepositFor(market, 70e6), 30e6); // headroom binds
        assertEq(rm.maxDepositFor(market, 96e6), 0); // headroom 4e6 < min 5e6
        assertEq(rm.maxDepositFor(market, 100e6), 0); // at cap
        assertEq(rm.maxDepositFor(market, 200e6), 0); // above cap

        vm.prank(admin);
        rm.pauseProtocol();
        assertEq(rm.maxDepositFor(market, 0), 0);
    }
}
