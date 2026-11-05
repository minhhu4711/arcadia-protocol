// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IRiskManager} from "./interfaces/IRiskManager.sol";

/// @notice Constructor-ready risk controls. Amounts use underlying base units (USDC: 6 decimals).
contract RiskManager is AccessControl, IRiskManager {
    bytes32 public constant RISK_ADMIN_ROLE = keccak256("RISK_ADMIN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bool public override protocolPaused;
    uint256 public defaultDepositCap;
    uint256 public defaultMaxDepositPerTx;
    uint256 public defaultMinDeposit;
    uint256 public defaultMaxWithdrawPerTx;
    mapping(address => MarketRisk) public marketRisks;

    error ZeroAddress();
    error InvalidRiskParameters();
    error ProtocolPaused();
    error BelowMinDeposit();
    error AboveMaxDepositPerTx();
    error DepositCapExceeded();
    error WithdrawalsPaused();
    error AboveMaxWithdrawPerTx();

    event ProtocolPauseChanged(bool paused);
    event DefaultsUpdated(uint256 depositCap, uint256 maxDepositPerTx, uint256 minDeposit, uint256 maxWithdrawPerTx);
    event MarketRiskUpdated(address indexed market, uint256 depositCap, uint256 maxDepositPerTx, uint256 minDeposit, uint256 maxWithdrawPerTx);
    event MarketRiskCleared(address indexed market);
    event WithdrawalsPauseChanged(address indexed market, bool paused);

    /// @notice Initialize defaults and grant all operational roles exclusively to explicit admin.
    constructor(address admin, uint256 depositCap_, uint256 maxDepositPerTx_, uint256 minDeposit_, uint256 maxWithdrawPerTx_) {
        if (admin == address(0)) revert ZeroAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(RISK_ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
        _setDefaults(depositCap_, maxDepositPerTx_, minDeposit_, maxWithdrawPerTx_);
    }

    /// @notice Pause both deposits and withdrawals protocol-wide.
    function pauseProtocol() external onlyRole(PAUSER_ROLE) {
        protocolPaused = true;
        emit ProtocolPauseChanged(true);
    }

    /// @notice Resume protocol-wide activity, retaining market-specific withdrawal pauses.
    function unpauseProtocol() external onlyRole(PAUSER_ROLE) {
        protocolPaused = false;
        emit ProtocolPauseChanged(false);
    }

    /// @notice Replace defaults. Zero withdrawal limit means unlimited.
    function setDefaults(uint256 cap, uint256 maxDeposit, uint256 minDeposit, uint256 maxWithdraw)
        external onlyRole(RISK_ADMIN_ROLE)
    {
        _setDefaults(cap, maxDeposit, minDeposit, maxWithdraw);
    }

    /// @notice Set a market override without altering its independently managed withdrawal pause.
    function setMarketRisk(address market, uint256 cap, uint256 maxDeposit, uint256 minDeposit, uint256 maxWithdraw)
        external onlyRole(RISK_ADMIN_ROLE)
    {
        if (market == address(0)) revert ZeroAddress();
        _validate(cap, maxDeposit, minDeposit);
        bool withdrawalPause = marketRisks[market].withdrawalsPaused;
        marketRisks[market] = MarketRisk(true, cap, maxDeposit, minDeposit, maxWithdraw, withdrawalPause);
        emit MarketRiskUpdated(market, cap, maxDeposit, minDeposit, maxWithdraw);
    }

    /// @notice Restore defaults without clearing a PAUSER-controlled withdrawal pause.
    function clearMarketRisk(address market) external onlyRole(RISK_ADMIN_ROLE) {
        if (market == address(0)) revert ZeroAddress();
        bool withdrawalPause = marketRisks[market].withdrawalsPaused;
        delete marketRisks[market];
        marketRisks[market].withdrawalsPaused = withdrawalPause;
        emit MarketRiskCleared(market);
    }

    /// @notice Set withdrawal pause independently of whether an override exists.
    function setWithdrawalsPaused(address market, bool value) external onlyRole(PAUSER_ROLE) {
        if (market == address(0)) revert ZeroAddress();
        marketRisks[market].withdrawalsPaused = value;
        emit WithdrawalsPauseChanged(market, value);
    }

    /// @inheritdoc IRiskManager
    function getRisk(address market) public view override returns (MarketRisk memory risk) {
        risk = marketRisks[market];
        if (!risk.configured) {
            risk.depositCap = defaultDepositCap;
            risk.maxDepositPerTx = defaultMaxDepositPerTx;
            risk.minDeposit = defaultMinDeposit;
            risk.maxWithdrawPerTx = defaultMaxWithdrawPerTx;
        }
    }

    /// @inheritdoc IRiskManager
    function validateDeposit(address market, uint256 amount, uint256 totalAssetsAfter) external view override {
        if (protocolPaused) revert ProtocolPaused();
        MarketRisk memory risk = getRisk(market);
        if (amount < risk.minDeposit) revert BelowMinDeposit();
        if (amount > risk.maxDepositPerTx) revert AboveMaxDepositPerTx();
        if (totalAssetsAfter > risk.depositCap) revert DepositCapExceeded();
    }

    /// @inheritdoc IRiskManager
    function validateWithdraw(address market, uint256 amount) external view override {
        if (protocolPaused) revert ProtocolPaused();
        MarketRisk memory risk = getRisk(market);
        if (risk.withdrawalsPaused) revert WithdrawalsPaused();
        if (risk.maxWithdrawPerTx != 0 && amount > risk.maxWithdrawPerTx) revert AboveMaxWithdrawPerTx();
    }

    /// @inheritdoc IRiskManager
    function maxDepositFor(address market, uint256 totalAssets) external view override returns (uint256) {
        if (protocolPaused) return 0;
        MarketRisk memory risk = getRisk(market);
        if (totalAssets >= risk.depositCap) return 0;
        uint256 maximum = Math.min(risk.depositCap - totalAssets, risk.maxDepositPerTx);
        return maximum < risk.minDeposit ? 0 : maximum;
    }

    function _setDefaults(uint256 cap, uint256 maxDeposit, uint256 minDeposit, uint256 maxWithdraw) private {
        _validate(cap, maxDeposit, minDeposit);
        defaultDepositCap = cap;
        defaultMaxDepositPerTx = maxDeposit;
        defaultMinDeposit = minDeposit;
        defaultMaxWithdrawPerTx = maxWithdraw;
        emit DefaultsUpdated(cap, maxDeposit, minDeposit, maxWithdraw);
    }

    function _validate(uint256 cap, uint256 maxDeposit, uint256 minDeposit) private pure {
        if (cap == 0 || minDeposit > maxDeposit || maxDeposit > cap) revert InvalidRiskParameters();
    }
}
