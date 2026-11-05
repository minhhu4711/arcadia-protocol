// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ArcadiaBase} from "./Arcadia.Base.t.sol";
import {LendingPoolHarness} from "./LendingPoolHarness.sol";
import {ArcadiaVault} from "../ArcadiaVault.sol";
import {RiskManager} from "../RiskManager.sol";
import {MockUSDC} from "./MockUSDC.sol";

/// @dev Drives the pool through bounded, mostly-successful actions.
contract PoolHandler is Test {
    LendingPoolHarness public pool;
    MockUSDC public usdc;
    RiskManager public rm;
    address public admin;
    address public borrower = address(0xB0B0);
    address[] public actors;
    uint256 public calls;

    constructor(LendingPoolHarness pool_, MockUSDC usdc_, RiskManager rm_, address admin_) {
        pool = pool_;
        usdc = usdc_;
        rm = rm_;
        admin = admin_;
        for (uint256 i; i < 4; i++) {
            address a = address(uint160(0xA000 + i));
            actors.push(a);
            vm.prank(a);
            usdc.approve(address(pool), type(uint256).max);
        }
        usdc.mint(borrower, 1_000_000_000e6);
        vm.prank(borrower);
        usdc.approve(address(pool), type(uint256).max);
    }

    function actorsLength() external view returns (uint256) {
        return actors.length;
    }

    function _actor(uint256 seed) internal view returns (address) {
        return actors[seed % actors.length];
    }

    function supply(uint256 seed, uint256 amount) external {
        address a = _actor(seed);
        uint256 room = rm.defaultDepositCap() > pool.totalSupplied() ? rm.defaultDepositCap() - pool.totalSupplied() : 0;
        uint256 maxAmt = room < rm.defaultMaxDepositPerTx() ? room : rm.defaultMaxDepositPerTx();
        if (maxAmt == 0) return;
        amount = bound(amount, 1, maxAmt);
        usdc.mint(a, amount);
        vm.prank(a);
        pool.supply(amount);
        calls++;
    }

    function withdraw(uint256 seed, uint256 amount) external {
        address a = _actor(seed);
        pool.accrueInterest();
        uint256 bal = pool.balanceOf(a);
        uint256 liq = pool.availableLiquidity();
        uint256 maxAmt = bal < liq ? bal : liq;
        if (maxAmt == 0) return;
        amount = bound(amount, 1, maxAmt);
        vm.prank(a);
        pool.withdraw(amount);
        calls++;
    }

    function withdrawAll(uint256 seed) external {
        address a = _actor(seed);
        pool.accrueInterest();
        uint256 bal = pool.balanceOf(a);
        if (bal == 0 || bal > pool.availableLiquidity()) return;
        vm.prank(a);
        pool.withdrawAll();
        calls++;
    }

    function borrow(uint256 amount) external {
        pool.accrueInterest();
        uint256 liq = pool.availableLiquidity();
        if (liq == 0) return;
        amount = bound(amount, 1, liq);
        pool.borrowTo(borrower, amount);
        calls++;
    }

    function repay(uint256 amount) external {
        pool.accrueInterest();
        uint256 debt = pool.totalBorrowed();
        if (debt == 0) return;
        amount = bound(amount, 1, debt);
        pool.repayFrom(borrower, amount);
        calls++;
    }

    function warp(uint256 dt) external {
        dt = bound(dt, 1, 90 days);
        vm.warp(block.timestamp + dt);
        pool.accrueInterest();
        calls++;
    }

    function donate(uint256 amount) external {
        amount = bound(amount, 0, 1_000_000e6);
        usdc.mint(address(pool), amount);
        calls++;
    }

    function withdrawReserves(uint256 amount) external {
        pool.accrueInterest();
        uint256 r = pool.totalReserves();
        uint256 liq = pool.availableLiquidity();
        uint256 maxAmt = r < liq ? r : liq;
        if (maxAmt == 0) return;
        amount = bound(amount, 1, maxAmt);
        vm.prank(admin);
        pool.withdrawReserves(admin, amount);
        calls++;
    }

    function sweep() external {
        uint256 bal = usdc.balanceOf(address(pool));
        if (bal <= pool.availableLiquidity()) return;
        vm.prank(admin);
        pool.sweepUnaccounted(admin);
        calls++;
    }

    function sumBalances() external view returns (uint256 s) {
        for (uint256 i; i < actors.length; i++) {
            s += pool.balanceOf(actors[i]);
        }
    }

    function sumShares() external view returns (uint256 s) {
        for (uint256 i; i < actors.length; i++) {
            s += pool.supplyShares(actors[i]);
        }
    }
}

contract PoolInvariantTest is ArcadiaBase {
    PoolHandler internal handler;

    function setUp() public override {
        super.setUp();
        handler = new PoolHandler(pool, usdc, rm, admin);
        targetContract(address(handler));
    }

    /// Σ lender claims never exceed accounted supply.
    function invariant_SumOfBalancesLeqTotalSupplied() public view {
        assertLe(handler.sumBalances(), pool.totalSupplied());
    }

    /// Lender shares are fully accounted for.
    function invariant_SharesConserved() public view {
        assertEq(handler.sumShares(), pool.totalSupplyShares());
    }

    /// Debt is always covered by lenders' supply plus reserves.
    function invariant_SuppliedPlusReservesCoverBorrowed() public view {
        assertGe(pool.totalSupplied() + pool.totalReserves(), pool.totalBorrowed());
    }

    /// Accounted liquidity is always physically present.
    function invariant_LiquidityBackedByTokens() public view {
        assertLe(pool.availableLiquidity(), usdc.balanceOf(address(pool)));
    }

    /// Borrow-free pools never owe more than cash + outstanding loans.
    function invariant_CashPlusDebtCoversClaims() public view {
        // tokens in pool + principal lent out >= supplied + reserves - accrued-interest-not-yet-repaid is
        // not directly observable; instead check liquidity identity.
        assertEq(
            pool.availableLiquidity(), pool.totalSupplied() + pool.totalReserves() - pool.totalBorrowed()
        );
    }
}

contract VaultHandler is Test {
    ArcadiaVault public vault;
    MockUSDC public usdc;
    address public admin;
    address[] public actors;

    constructor(ArcadiaVault vault_, MockUSDC usdc_, address admin_) {
        vault = vault_;
        usdc = usdc_;
        admin = admin_;
        for (uint256 i; i < 4; i++) {
            address a = address(uint160(0xC000 + i));
            actors.push(a);
            vm.prank(a);
            usdc.approve(address(vault), type(uint256).max);
        }
    }

    function _actor(uint256 seed) internal view returns (address) {
        return actors[seed % actors.length];
    }

    function deposit(uint256 seed, uint256 amount) external {
        address a = _actor(seed);
        uint256 maxAmt = vault.maxDeposit(a);
        if (maxAmt == 0) return;
        amount = bound(amount, 1, maxAmt);
        usdc.mint(a, amount);
        vm.prank(a);
        vault.deposit(amount, a);
    }

    function mint(uint256 seed, uint256 shares) external {
        address a = _actor(seed);
        uint256 maxShares = vault.maxMint(a);
        if (maxShares == 0) return;
        shares = bound(shares, 1, maxShares);
        uint256 cost = vault.previewMint(shares);
        if (cost == 0 || cost > vault.maxDeposit(a)) return;
        usdc.mint(a, cost);
        vm.prank(a);
        vault.mint(shares, a);
    }

    function withdraw(uint256 seed, uint256 amount) external {
        address a = _actor(seed);
        uint256 maxAmt = vault.maxWithdraw(a);
        if (maxAmt == 0) return;
        amount = bound(amount, 1, maxAmt);
        vm.prank(a);
        vault.withdraw(amount, a, a);
    }

    function redeem(uint256 seed, uint256 shares) external {
        address a = _actor(seed);
        uint256 maxShares = vault.maxRedeem(a);
        if (maxShares < 1e6) return; // sub-wei share amounts redeem to zero assets
        shares = bound(shares, 1e6, maxShares);
        vm.prank(a);
        vault.redeem(shares, a, a);
    }

    function donate(uint256 amount) external {
        amount = bound(amount, 0, 1_000_000e6);
        usdc.mint(address(vault), amount);
    }

    function sweep() external {
        if (usdc.balanceOf(address(vault)) <= vault.accountedAssets()) return;
        vm.prank(admin);
        vault.sweepUnaccounted(admin);
    }

    function sumShares() external view returns (uint256 s) {
        for (uint256 i; i < actors.length; i++) {
            s += vault.balanceOf(actors[i]);
        }
    }
}

contract VaultInvariantTest is ArcadiaBase {
    VaultHandler internal handler;

    function setUp() public override {
        super.setUp();
        handler = new VaultHandler(vault, usdc, admin);
        targetContract(address(handler));
    }

    function invariant_TotalAssetsEqualsAccounted() public view {
        assertEq(vault.totalAssets(), vault.accountedAssets());
    }

    function invariant_AccountedLeqTokenBalance() public view {
        assertLe(vault.accountedAssets(), usdc.balanceOf(address(vault)));
    }

    function invariant_ConvertToAssetsOfSupplyLeqTotalAssets() public view {
        assertLe(vault.convertToAssets(vault.totalSupply()), vault.totalAssets());
    }

    function invariant_SharesConserved() public view {
        assertEq(handler.sumShares(), vault.totalSupply());
    }

    function invariant_SharePriceFixed() public view {
        assertEq(vault.sharePrice(), 1e6);
    }
}
