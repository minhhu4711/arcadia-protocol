// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ArcadiaBase} from "./Arcadia.Base.t.sol";
import {ArcadiaFactory} from "../ArcadiaFactory.sol";
import {LendingPool} from "../LendingPool.sol";
import {MockUSDC, MockDecimalsToken, NoDecimalsContract} from "./MockUSDC.sol";

contract ArcadiaFactoryTest is ArcadiaBase {
    MockUSDC internal tokenB;

    function setUp() public override {
        super.setUp();
        tokenB = new MockUSDC();
    }

    // ------------------------------------------------------------ constructor
    function test_Constructor_CreatesUsdcMarket() public view {
        address m = factory.marketFor(address(usdc));
        assertTrue(m != address(0));
        assertTrue(factory.isMarket(m));
        assertTrue(factory.isSupportedAsset(address(usdc)));
        assertEq(factory.marketsLength(), 1);
        assertEq(factory.allMarkets()[0], m);

        LendingPool p = LendingPool(m);
        assertEq(address(p.asset()), address(usdc));
        assertEq(address(p.riskManager()), address(rm));
        assertEq(address(p.interestRateModel()), address(irm));
        assertEq(p.reserveFactorWad(), RF);
        // pool administered by the explicit admin, never by the factory or deployer
        assertTrue(p.hasRole(ADMIN_ROLE, admin));
        assertTrue(p.hasRole(PAUSER_ROLE, admin));
        assertTrue(p.hasRole(DEFAULT_ADMIN_ROLE, admin));
        assertFalse(p.hasRole(DEFAULT_ADMIN_ROLE, address(factory)));
        assertFalse(p.hasRole(DEFAULT_ADMIN_ROLE, address(this)));
    }

    function test_Constructor_ImmutablesAndRoles() public view {
        assertEq(factory.riskManager(), address(rm));
        assertEq(factory.rateModel(), address(irm));
        assertEq(factory.marketAdmin(), admin);
        assertTrue(factory.hasRole(DEFAULT_ADMIN_ROLE, admin));
        assertTrue(factory.hasRole(ADMIN_ROLE, admin));
        assertTrue(factory.hasRole(MARKET_CREATOR_ROLE, admin));
        assertFalse(factory.hasRole(ADMIN_ROLE, address(this)));
    }

    function test_Constructor_EmitsAssetSupportedAndMarketCreated() public {
        vm.expectEmit(true, false, false, false);
        emit ArcadiaFactory.AssetSupported(address(tokenB));
        vm.expectEmit(true, false, true, true);
        emit ArcadiaFactory.MarketCreated(address(tokenB), address(0), admin, RF, 0);
        new ArcadiaFactory(admin, address(rm), address(irm), address(tokenB), RF);
    }

    function test_Constructor_ZeroAddressesRevert() public {
        vm.expectRevert(ArcadiaFactory.ZeroAddress.selector);
        new ArcadiaFactory(address(0), address(rm), address(irm), address(usdc), RF);
        vm.expectRevert(ArcadiaFactory.ZeroAddress.selector);
        new ArcadiaFactory(admin, address(0), address(irm), address(usdc), RF);
        vm.expectRevert(ArcadiaFactory.ZeroAddress.selector);
        new ArcadiaFactory(admin, address(rm), address(0), address(usdc), RF);
        vm.expectRevert(ArcadiaFactory.ZeroAddress.selector);
        new ArcadiaFactory(admin, address(rm), address(irm), address(0), RF);
    }

    function test_Constructor_InvalidContractsRevert() public {
        vm.expectRevert(ArcadiaFactory.InvalidContract.selector);
        new ArcadiaFactory(admin, makeAddr("eoa"), address(irm), address(usdc), RF);
        vm.expectRevert(ArcadiaFactory.InvalidContract.selector);
        new ArcadiaFactory(admin, address(rm), makeAddr("eoa"), address(usdc), RF);
        vm.expectRevert(ArcadiaFactory.InvalidContract.selector);
        new ArcadiaFactory(admin, address(rm), address(irm), makeAddr("eoa"), RF);
    }

    function test_Constructor_InvalidAssetAndReserveFactorRevert() public {
        MockDecimalsToken t18 = new MockDecimalsToken(18);
        vm.expectRevert(ArcadiaFactory.InvalidAsset.selector);
        new ArcadiaFactory(admin, address(rm), address(irm), address(t18), RF);
        NoDecimalsContract nd = new NoDecimalsContract();
        vm.expectRevert(ArcadiaFactory.InvalidAsset.selector);
        new ArcadiaFactory(admin, address(rm), address(irm), address(nd), RF);
        vm.expectRevert(ArcadiaFactory.InvalidReserveFactor.selector);
        new ArcadiaFactory(admin, address(rm), address(irm), address(usdc), 0.5e18 + 1);
    }

    // ------------------------------------------------------------ supported assets
    function test_AddSupportedAsset_Valid_AndEvent() public {
        vm.expectEmit(true, false, false, false, address(factory));
        emit ArcadiaFactory.AssetSupported(address(tokenB));
        vm.prank(admin);
        factory.addSupportedAsset(address(tokenB));
        assertTrue(factory.isSupportedAsset(address(tokenB)));
        assertEq(factory.marketFor(address(tokenB)), address(0)); // support alone creates no market
    }

    function test_AddSupportedAsset_Reverts() public {
        MockDecimalsToken t18 = new MockDecimalsToken(18);
        vm.startPrank(admin);
        vm.expectRevert(ArcadiaFactory.ZeroAddress.selector);
        factory.addSupportedAsset(address(0));
        vm.expectRevert(ArcadiaFactory.InvalidContract.selector);
        factory.addSupportedAsset(makeAddr("eoa"));
        vm.expectRevert(ArcadiaFactory.AssetAlreadySupported.selector);
        factory.addSupportedAsset(address(usdc));
        vm.expectRevert(ArcadiaFactory.InvalidAsset.selector);
        factory.addSupportedAsset(address(t18));
        vm.stopPrank();
    }

    function test_RemoveSupportedAsset_Valid_KeepsExistingMarket() public {
        address m = factory.marketFor(address(usdc));
        vm.expectEmit(true, false, false, false, address(factory));
        emit ArcadiaFactory.AssetRemoved(address(usdc));
        vm.prank(admin);
        factory.removeSupportedAsset(address(usdc));
        assertFalse(factory.isSupportedAsset(address(usdc)));
        assertEq(factory.marketFor(address(usdc)), m);
        assertTrue(factory.isMarket(m));
        // existing pool still serves users
        vm.startPrank(alice);
        usdc.approve(m, type(uint256).max);
        LendingPool(m).supply(10e6);
        vm.stopPrank();
    }

    function test_RemoveSupportedAsset_Reverts() public {
        vm.startPrank(admin);
        vm.expectRevert(ArcadiaFactory.ZeroAddress.selector);
        factory.removeSupportedAsset(address(0));
        vm.expectRevert(ArcadiaFactory.UnsupportedAsset.selector);
        factory.removeSupportedAsset(address(tokenB));
        vm.stopPrank();
    }

    // ------------------------------------------------------------ createMarket
    function test_CreateMarket_Valid() public {
        vm.prank(admin);
        factory.addSupportedAsset(address(tokenB));

        vm.expectEmit(true, false, true, true, address(factory));
        emit ArcadiaFactory.MarketCreated(address(tokenB), address(0), admin, 0.2e18, 1);
        vm.prank(admin);
        address m = factory.createMarket(address(tokenB), 0.2e18);

        assertEq(factory.marketFor(address(tokenB)), m);
        assertTrue(factory.isMarket(m));
        assertEq(factory.marketsLength(), 2);
        assertEq(factory.allMarkets()[1], m);
        assertEq(address(LendingPool(m).asset()), address(tokenB));
        assertEq(LendingPool(m).reserveFactorWad(), 0.2e18);
        assertTrue(LendingPool(m).hasRole(ADMIN_ROLE, admin));
        assertFalse(LendingPool(m).hasRole(ADMIN_ROLE, address(factory)));
    }

    function test_CreateMarket_CreatorRoleHolderDoesNotBecomePoolAdmin() public {
        vm.startPrank(admin);
        factory.addSupportedAsset(address(tokenB));
        factory.grantRole(MARKET_CREATOR_ROLE, alice);
        vm.stopPrank();
        vm.prank(alice);
        address m = factory.createMarket(address(tokenB), RF);
        assertFalse(LendingPool(m).hasRole(ADMIN_ROLE, alice));
        assertFalse(LendingPool(m).hasRole(DEFAULT_ADMIN_ROLE, alice));
        assertTrue(LendingPool(m).hasRole(DEFAULT_ADMIN_ROLE, admin));
    }

    function test_CreateMarket_OnlySupportedAssets() public {
        vm.prank(admin);
        vm.expectRevert(ArcadiaFactory.UnsupportedAsset.selector);
        factory.createMarket(address(tokenB), RF);
    }

    function test_CreateMarket_OnePerAsset() public {
        vm.prank(admin);
        vm.expectRevert(ArcadiaFactory.MarketAlreadyExists.selector);
        factory.createMarket(address(usdc), RF);
    }

    function test_CreateMarket_AfterRemovalOfSupport_Reverts() public {
        vm.startPrank(admin);
        factory.addSupportedAsset(address(tokenB));
        factory.removeSupportedAsset(address(tokenB));
        vm.expectRevert(ArcadiaFactory.UnsupportedAsset.selector);
        factory.createMarket(address(tokenB), RF);
        vm.stopPrank();
    }

    function test_CreateMarket_InvalidReserveFactorReverts() public {
        vm.startPrank(admin);
        factory.addSupportedAsset(address(tokenB));
        vm.expectRevert(ArcadiaFactory.InvalidReserveFactor.selector);
        factory.createMarket(address(tokenB), 0.5e18 + 1);
        address m = factory.createMarket(address(tokenB), 0.5e18);
        vm.stopPrank();
        assertEq(LendingPool(m).reserveFactorWad(), 0.5e18);
    }

    // ------------------------------------------------------------ access control
    function test_Unauthorized_AddSupportedAsset() public {
        vm.prank(stranger);
        _expectUnauth(stranger, ADMIN_ROLE);
        factory.addSupportedAsset(address(tokenB));
    }

    function test_Unauthorized_RemoveSupportedAsset() public {
        vm.prank(stranger);
        _expectUnauth(stranger, ADMIN_ROLE);
        factory.removeSupportedAsset(address(usdc));
    }

    function test_Unauthorized_CreateMarket() public {
        vm.prank(admin);
        factory.addSupportedAsset(address(tokenB));
        vm.prank(stranger);
        _expectUnauth(stranger, MARKET_CREATOR_ROLE);
        factory.createMarket(address(tokenB), RF);
    }

    function test_MarketCreatorCannotAddAssets() public {
        vm.prank(admin);
        factory.grantRole(MARKET_CREATOR_ROLE, alice);
        vm.prank(alice);
        _expectUnauth(alice, ADMIN_ROLE);
        factory.addSupportedAsset(address(tokenB));
    }
}
