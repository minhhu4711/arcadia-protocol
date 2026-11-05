// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IRiskManager} from "./interfaces/IRiskManager.sol";

/// @notice Fixed-price USDC custody vault. Does NOT generate yield; UIs must not advertise APY.
/// @dev Local pause blocks deposit/mint, not withdraw/redeem. RiskManager can block both.
/// USDC has 6 asset decimals; shares have 12 decimals. One whole share is one whole USDC.
/// Only standard non-fee, non-rebasing assets are supported. Donations never change price.
contract ArcadiaVault is ERC4626, Pausable, AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    uint256 private constant SHARE_SCALE = 1e6;
    IRiskManager public immutable riskManager;
    uint256 public accountedAssets;

    error ZeroAddress();
    error ZeroAmount();
    error InvalidContract();
    error InvalidAssetDecimals();
    error AccountingDeficit();
    event UnaccountedSwept(address indexed to, uint256 amount);
    event VaultPaused(address indexed caller, bool paused);

    /// @notice Configure USDC, risk controls, share metadata and explicit administrator at construction.
    constructor(address asset_, address riskManager_, address admin, string memory name_, string memory symbol_)
        ERC20(name_, symbol_) ERC4626(IERC20(asset_))
    {
        if (admin == address(0) || asset_ == address(0) || riskManager_ == address(0)) revert ZeroAddress();
        if (asset_.code.length == 0 || riskManager_.code.length == 0) revert InvalidContract();
        if (IERC20Metadata(asset_).decimals() != 6) revert InvalidAssetDecimals();
        riskManager = IRiskManager(riskManager_);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
    }

    /// @notice Pause new deposits/mints; emergency withdrawals still obey RiskManager.
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
        emit VaultPaused(msg.sender, true);
    }

    /// @notice Resume deposits/mints, subject to RiskManager.
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
        emit VaultPaused(msg.sender, false);
    }

    /// @notice Internal accounted assets only; excludes unsolicited transfers.
    function totalAssets() public view override returns (uint256) {
        return accountedAssets;
    }

    /// @notice Maximum asset deposit after local pause, risk cap/minimum and per-transaction limit.
    function maxDeposit(address receiver) public view override returns (uint256) {
        if (receiver == address(0) || paused()) return 0;
        uint256 maximum = Math.min(riskManager.maxDepositFor(address(this), accountedAssets),
            (type(uint256).max - totalSupply()) / SHARE_SCALE);
        IRiskManager.MarketRisk memory risk = riskManager.getRisk(address(this));
        return maximum < risk.minDeposit ? 0 : maximum;
    }

    /// @notice Maximum shares mintable, applying the same asset-denominated limits as deposits.
    function maxMint(address receiver) public view override returns (uint256) {
        return convertToShares(maxDeposit(receiver));
    }

    /// @notice Maximum assets withdrawable in one transaction. Ignores local pause deliberately.
    function maxWithdraw(address owner) public view override returns (uint256) {
        if (riskManager.protocolPaused()) return 0;
        IRiskManager.MarketRisk memory risk = riskManager.getRisk(address(this));
        if (risk.withdrawalsPaused) return 0;
        uint256 maximum = Math.min(convertToAssets(balanceOf(owner)), accountedAssets);
        return risk.maxWithdrawPerTx == 0 ? maximum : Math.min(maximum, risk.maxWithdrawPerTx);
    }

    /// @notice Maximum shares redeemable under RiskManager controls; ignores local pause.
    function maxRedeem(address owner) public view override returns (uint256) {
        if (riskManager.protocolPaused()) return 0;
        IRiskManager.MarketRisk memory risk = riskManager.getRisk(address(this));
        if (risk.withdrawalsPaused) return 0;
        uint256 owned = balanceOf(owner);
        uint256 maximum = Math.min(convertToAssets(owned), accountedAssets);
        if (risk.maxWithdrawPerTx != 0) maximum = Math.min(maximum, risk.maxWithdrawPerTx);
        // Retain all fractional shares when redeeming the entire balance is within the limit.
        if (convertToAssets(owned) <= maximum) return owned;
        return convertToShares(maximum);
    }

    /// @notice Asset base units per whole share: convertToAssets(10**decimals()), always 1e6.
    /// @dev No yield is produced. The UI must not advertise an APY.
    function sharePrice() external view returns (uint256) {
        return convertToAssets(10 ** decimals());
    }

    /// @notice Sweep unsolicited USDC only; does not change accountedAssets or share price.
    function sweepUnaccounted(address to) external onlyRole(ADMIN_ROLE) nonReentrant returns (uint256 amount) {
        if (to == address(0)) revert ZeroAddress();
        IERC20 token = IERC20(asset());
        uint256 actual = token.balanceOf(address(this));
        if (actual < accountedAssets) revert AccountingDeficit();
        amount = actual - accountedAssets;
        if (amount == 0) revert ZeroAmount();
        token.safeTransfer(to, amount);
        emit UnaccountedSwept(to, amount);
    }

    /// @dev Additional share precision; fixed conversions below prevent donation and rounding-dust repricing.
    function _decimalsOffset() internal pure override returns (uint8) {
        return 6;
    }

    /// @dev Fixed exchange rate is intentional: this MVP has no yield or loss allocation.
    /// Fractional-share rounding surplus remains accounted but is never repriced into other shares.
    function _convertToShares(uint256 assets, Math.Rounding) internal pure override returns (uint256) {
        return Math.mulDiv(assets, SHARE_SCALE, 1);
    }

    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal pure override returns (uint256) {
        return Math.mulDiv(shares, 1, SHARE_SCALE, rounding);
    }

    /// @dev Covers both inherited deposit/mint entry points with a single reentrancy lock.
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares)
        internal override nonReentrant whenNotPaused
    {
        if (receiver == address(0)) revert ZeroAddress();
        if (assets == 0 || shares == 0) revert ZeroAmount();
        riskManager.validateDeposit(address(this), assets, accountedAssets + assets);
        accountedAssets += assets;
        _mint(receiver, shares);
        IERC20(asset()).safeTransferFrom(caller, address(this), assets);
        emit Deposit(caller, receiver, assets, shares);
    }

    /// @dev Covers inherited withdraw/redeem. CEI; never blocked by local pause.
    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares)
        internal override nonReentrant
    {
        if (receiver == address(0) || owner == address(0)) revert ZeroAddress();
        if (assets == 0 || shares == 0) revert ZeroAmount();
        riskManager.validateWithdraw(address(this), assets);
        if (caller != owner) _spendAllowance(owner, caller, shares);
        accountedAssets -= assets;
        _burn(owner, shares);
        IERC20(asset()).safeTransfer(receiver, assets);
        emit Withdraw(caller, receiver, owner, assets, shares);
    }
}
