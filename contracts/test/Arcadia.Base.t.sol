// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {RiskManager} from "../RiskManager.sol";
import {InterestRateModel} from "../InterestRateModel.sol";
import {ArcadiaVault} from "../ArcadiaVault.sol";
import {ArcadiaFactory} from "../ArcadiaFactory.sol";
import {MockUSDC} from "./MockUSDC.sol";
import {LendingPoolHarness} from "./LendingPoolHarness.sol";

/// @dev Shared fixture. No test/fuzz/invariant functions here.
abstract contract ArcadiaBase is Test {
    bytes32 internal constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 internal constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 internal constant RISK_ADMIN_ROLE = keccak256("RISK_ADMIN_ROLE");
    bytes32 internal constant MARKET_CREATOR_ROLE = keccak256("MARKET_CREATOR_ROLE");
    bytes32 internal constant DEFAULT_ADMIN_ROLE = 0x00;

    uint256 internal constant CAP = 5_000_000e6;
    uint256 internal constant MAX_DEP = 1_000_000e6;
    uint256 internal constant MIN_DEP = 1;
    uint256 internal constant MAX_WD = 0; // unlimited
    uint256 internal constant RF = 0.1e18;
    uint256 internal constant WAD = 1e18;
    uint256 internal constant YEAR = 365 days;

    // IRM: base 2%, optimal 80%, slope1 4%, slope2 75%
    uint256 internal constant BASE = 0.02e18;
    uint256 internal constant OPT = 0.8e18;
    uint256 internal constant S1 = 0.04e18;
    uint256 internal constant S2 = 0.75e18;

    address internal admin = makeAddr("admin");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");
    address internal attacker = makeAddr("attacker");
    address internal stranger = makeAddr("stranger");
    address internal treasury = makeAddr("treasury");
    address internal borrower = makeAddr("borrower");

    MockUSDC internal usdc;
    RiskManager internal rm;
    InterestRateModel internal irm;
    LendingPoolHarness internal pool;
    ArcadiaVault internal vault;
    ArcadiaFactory internal factory;

    function setUp() public virtual {
        usdc = new MockUSDC();
        rm = new RiskManager(admin, CAP, MAX_DEP, MIN_DEP, MAX_WD);
        irm = new InterestRateModel(admin, BASE, OPT, S1, S2);
        pool = new LendingPoolHarness(address(usdc), address(rm), address(irm), admin, RF);
        vault = new ArcadiaVault(address(usdc), address(rm), admin, "Arcadia USDC Vault", "aUSDC");
        factory = new ArcadiaFactory(admin, address(rm), address(irm), address(usdc), RF);

        address[5] memory users = [alice, bob, carol, attacker, borrower];
        for (uint256 i; i < users.length; i++) {
            usdc.mint(users[i], 10_000_000e6);
            vm.startPrank(users[i]);
            usdc.approve(address(pool), type(uint256).max);
            usdc.approve(address(vault), type(uint256).max);
            vm.stopPrank();
        }
    }

    // ---------------------------------------------------------------- helpers
    function _expectUnauth(address who, bytes32 role) internal {
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, who, role));
    }

    function _supply(address user, uint256 amount) internal returns (uint256 shares) {
        vm.prank(user);
        shares = pool.supply(amount);
    }

    function _vaultDeposit(address user, uint256 amount) internal returns (uint256 shares) {
        vm.prank(user);
        shares = vault.deposit(amount, user);
    }

    function _donate(address to, uint256 amount) internal {
        usdc.mint(to, amount);
    }

    function _borrow(uint256 amount) internal {
        pool.borrowTo(borrower, amount);
    }
}
