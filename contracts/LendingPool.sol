// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IRiskManager} from "./interfaces/IRiskManager.sol";
import {IInterestRateModel} from "./interfaces/IInterestRateModel.sol";
import {ILendingPool} from "./interfaces/ILendingPool.sol";

/// @notice Accounted-USDC supply market. Borrowing is NOT live: no external borrow/repay entry points.
/// @dev Supply APY is zero until a future collateral-enabled implementation activates borrowing.
/// Donations never enter accounting. Local pause blocks supply only; emergency exits remain subject
/// to RiskManager protocol/withdrawal pauses. Supports only standard, non-rebasing, non-fee USDC.
contract LendingPool is AccessControl, Pausable, ReentrancyGuard, ILendingPool {
    using SafeERC20 for IERC20;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    uint256 public constant WAD = 1e18;
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant VIRTUAL_SHARES = 1e6;
    IERC20 public immutable asset;
    IRiskManager public immutable riskManager;
    IInterestRateModel public immutable interestRateModel;
    uint256 public immutable reserveFactorWad;
    mapping(address => uint256) public supplyShares;
    uint256 public totalSupplyShares;
    uint256 public totalSupplied;
    uint256 public totalBorrowed;
    uint256 public totalReserves;
    uint256 public lastAccrual;

    error ZeroAddress();
    error ZeroAmount();
    error InvalidContract();
    error InvalidAssetDecimals();
    error InvalidReserveFactor();
    error InsufficientLiquidity();
    error InsufficientShares();
    error InsufficientReserves();
    error InvalidRepayment();
    error AccountingDeficit();

    event Supply(address indexed user, address indexed onBehalfOf, uint256 amount, uint256 shares);
    event Withdraw(address indexed user, uint256 amount, uint256 shares);
    event InterestAccrued(uint256 interest, uint256 reserveCut, uint256 borrowRate, uint256 newTotalBorrowed, uint256 newTotalSupplied, uint256 timestamp);
    event ReservesWithdrawn(address indexed to, uint256 amount);
    event UnaccountedSwept(address indexed to, uint256 amount);

    /// @notice Wire all dependencies and grant admin roles without follow-up initialization.
    /// @param reserveFactorWad_ Fraction of accrued interest assigned to reserves, at most 0.5e18.
    constructor(address asset_, address riskManager_, address rateModel_, address admin, uint256 reserveFactorWad_) {
        if (admin == address(0) || asset_ == address(0) || riskManager_ == address(0) || rateModel_ == address(0)) revert ZeroAddress();
        if (asset_.code.length == 0 || riskManager_.code.length == 0 || rateModel_.code.length == 0) revert InvalidContract();
        if (IERC20Metadata(asset_).decimals() != 6) revert InvalidAssetDecimals();
        if (reserveFactorWad_ > 0.5e18) revert InvalidReserveFactor();
        asset = IERC20(asset_);
        riskManager = IRiskManager(riskManager_);
        interestRateModel = IInterestRateModel(rateModel_);
        reserveFactorWad = reserveFactorWad_;
        lastAccrual = block.timestamp;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
    }

    /// @notice Pause supplies; withdrawals remain available subject to RiskManager.
    function pause() external onlyRole(PAUSER_ROLE) nonReentrant {
        _accrueInterest();
        _pause();
    }

    /// @notice Resume supplies.
    function unpause() external onlyRole(PAUSER_ROLE) nonReentrant {
        _accrueInterest();
        _unpause();
    }

    /// @inheritdoc ILendingPool
    function supply(uint256 amount) external override nonReentrant whenNotPaused returns (uint256 shares) {
        return _supply(msg.sender, amount);
    }

    /// @inheritdoc ILendingPool
    function supplyFor(address onBehalfOf, uint256 amount) external override nonReentrant whenNotPaused returns (uint256 shares) {
        return _supply(onBehalfOf, amount);
    }

    function _supply(address onBehalfOf, uint256 amount) private returns (uint256 shares) {
        _accrueInterest();
        if (onBehalfOf == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        riskManager.validateDeposit(address(this), amount, totalSupplied + amount);
        shares = Math.mulDiv(amount, totalSupplyShares + VIRTUAL_SHARES, totalSupplied + 1);
        if (shares == 0) revert ZeroAmount();
        supplyShares[onBehalfOf] += shares;
        totalSupplyShares += shares;
        totalSupplied += amount;
        asset.safeTransferFrom(msg.sender, address(this), amount);
        emit Supply(msg.sender, onBehalfOf, amount, shares);
    }

    /// @inheritdoc ILendingPool
    /// @dev Emergency exit ignores local pause, but never bypasses RiskManager pause flags.
    function withdraw(uint256 amount) external override nonReentrant returns (uint256 shares) {
        _accrueInterest();
        if (amount == 0) revert ZeroAmount();
        shares = Math.mulDiv(amount, totalSupplyShares + VIRTUAL_SHARES, totalSupplied + 1, Math.Rounding.Ceil);
        _withdraw(amount, shares);
    }

    /// @inheritdoc ILendingPool
    /// @dev Burns all shares, including rounding dust; may revert if a per-transaction limit requires partial exits.
    function withdrawAll() external override nonReentrant returns (uint256 amount) {
        _accrueInterest();
        uint256 shares = supplyShares[msg.sender];
        amount = Math.mulDiv(shares, totalSupplied + 1, totalSupplyShares + VIRTUAL_SHARES);
        if (amount == 0) revert ZeroAmount();
        _withdraw(amount, shares);
    }

    function _withdraw(uint256 amount, uint256 shares) private {
        riskManager.validateWithdraw(address(this), amount);
        if (amount > availableLiquidity() || amount > Math.mulDiv(supplyShares[msg.sender], totalSupplied + 1, totalSupplyShares + VIRTUAL_SHARES)) revert InsufficientLiquidity();
        if (shares > supplyShares[msg.sender]) revert InsufficientShares();
        supplyShares[msg.sender] -= shares;
        totalSupplyShares -= shares;
        totalSupplied -= amount;
        asset.safeTransfer(msg.sender, amount);
        emit Withdraw(msg.sender, amount, shares);
    }

    /// @inheritdoc ILendingPool
    function accrueInterest() external override nonReentrant {
        _accrueInterest();
    }

    function _accrueInterest() internal {
        uint256 dt = block.timestamp - lastAccrual;
        if (dt == 0) return;
        uint256 rate = interestRateModel.getBorrowRate(interestRateModel.utilization(availableLiquidity(), totalBorrowed));
        // rate <= 10e18 in the immutable protocol model; realistic timestamp intervals fit uint256.
        uint256 interest = Math.mulDiv(totalBorrowed, rate * dt, SECONDS_PER_YEAR * WAD);
        uint256 cut = Math.mulDiv(interest, reserveFactorWad, WAD);
        totalBorrowed += interest;
        totalSupplied += interest - cut;
        totalReserves += cut;
        lastAccrual = block.timestamp;
        emit InterestAccrued(interest, cut, rate, totalBorrowed, totalSupplied, block.timestamp);
    }

    /// @notice Account-only future borrow hook; NOT an external unsecured lending feature.
    /// @dev Derived collateral implementation must authorize/health-check, use nonReentrant,
    /// enforce pauses, and transfer exactly amount OUT atomically after this accounting effect.
    function _recordBorrow(uint256 amount) internal virtual {
        _accrueInterest();
        if (amount == 0) revert ZeroAmount();
        if (amount > availableLiquidity()) revert InsufficientLiquidity();
        totalBorrowed += amount;
    }

    /// @notice Account-only future repay hook; principalAndInterest is denominated in asset base units.
    /// @dev Derived implementation must use nonReentrant and collect exactly this amount in the same
    /// transaction. This hook neither transfers tokens nor tracks borrower-specific debt.
    function _recordRepay(uint256 principalAndInterest) internal virtual {
        _accrueInterest();
        if (principalAndInterest == 0) revert ZeroAmount();
        if (principalAndInterest > totalBorrowed) revert InvalidRepayment();
        totalBorrowed -= principalAndInterest;
    }

    /// @notice Withdraw earned reserves, never lender principal; bounded by accounted cash.
    function withdrawReserves(address to, uint256 amount) external onlyRole(ADMIN_ROLE) nonReentrant {
        _accrueInterest();
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (amount > totalReserves) revert InsufficientReserves();
        if (amount > availableLiquidity()) revert InsufficientLiquidity();
        totalReserves -= amount;
        asset.safeTransfer(to, amount);
        emit ReservesWithdrawn(to, amount);
    }

    /// @notice Recover only unsolicited asset transfers, without altering accounted assets.
    function sweepUnaccounted(address to) external onlyRole(ADMIN_ROLE) nonReentrant returns (uint256 amount) {
        _accrueInterest();
        if (to == address(0)) revert ZeroAddress();
        uint256 actual = asset.balanceOf(address(this));
        uint256 accounted = availableLiquidity();
        if (actual < accounted) revert AccountingDeficit();
        amount = actual - accounted;
        if (amount == 0) revert ZeroAmount();
        asset.safeTransfer(to, amount);
        emit UnaccountedSwept(to, amount);
    }

    /// @inheritdoc ILendingPool
    /// @dev Accrual adds equal assets and debt, so pending interest cannot change cash.
    function availableLiquidity() public view override returns (uint256) {
        return totalSupplied + totalReserves - totalBorrowed;
    }

    function _pending() private view returns (uint256 supplied, uint256 borrowed, uint256 reserves) {
        uint256 rate = interestRateModel.getBorrowRate(interestRateModel.utilization(availableLiquidity(), totalBorrowed));
        uint256 interest = Math.mulDiv(totalBorrowed, rate * (block.timestamp - lastAccrual), SECONDS_PER_YEAR * WAD);
        uint256 cut = Math.mulDiv(interest, reserveFactorWad, WAD);
        return (totalSupplied + interest - cut, totalBorrowed + interest, totalReserves + cut);
    }

    /// @notice Shares minted for an asset deposit, rounded down; includes pending interest, excludes risk checks.
    function previewSupply(uint256 amount) public view returns (uint256) {
        (uint256 supplied,,) = _pending();
        return Math.mulDiv(amount, totalSupplyShares + VIRTUAL_SHARES, supplied + 1);
    }

    /// @notice Shares burned for an asset withdrawal, rounded up; excludes risk/liquidity checks.
    function previewWithdraw(uint256 amount) public view returns (uint256) {
        (uint256 supplied,,) = _pending();
        return Math.mulDiv(amount, totalSupplyShares + VIRTUAL_SHARES, supplied + 1, Math.Rounding.Ceil);
    }

    /// @notice Assets redeemed for shares, rounded down; excludes risk/liquidity checks.
    function previewRedeem(uint256 shares) public view returns (uint256) {
        (uint256 supplied,,) = _pending();
        return Math.mulDiv(shares, supplied + 1, totalSupplyShares + VIRTUAL_SHARES);
    }

    /// @inheritdoc ILendingPool
    function balanceOf(address user) public view override returns (uint256) {
        return previewRedeem(supplyShares[user]);
    }

    /// @notice Current utilization in WAD, including pending debt interest.
    function utilization() public view returns (uint256) {
        (,uint256 borrowed,) = _pending();
        return interestRateModel.utilization(availableLiquidity(), borrowed);
    }

    /// @notice Annual quoted borrow rate in WAD; borrowing itself is not live.
    function borrowRate() public view returns (uint256) {
        return interestRateModel.getBorrowRate(utilization());
    }

    /// @notice Annual quoted supply rate in WAD; zero until borrowing is enabled in a future version.
    function supplyRate() public view returns (uint256) {
        return interestRateModel.getSupplyRate(utilization(), reserveFactorWad);
    }

    /// @inheritdoc ILendingPool
    function getMarketState() external view override returns (MarketState memory state) {
        (state.supplied, state.borrowed, state.reserves) = _pending();
        state.shares = totalSupplyShares;
        state.liquidity = availableLiquidity();
        state.utilizationWad = interestRateModel.utilization(state.liquidity, state.borrowed);
        state.borrowRateWad = interestRateModel.getBorrowRate(state.utilizationWad);
        state.supplyRateWad = interestRateModel.getSupplyRate(state.utilizationWad, reserveFactorWad);
        state.lastAccrual = lastAccrual;
    }
}
