// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {LendingPool} from "./LendingPool.sol";

/// @notice Constructor-ready market registry. The initial asset should be Arc Testnet USDC:
/// 0x3600000000000000000000000000000000000000 (6 decimals). No follow-up setup is required.
/// @dev Only the explicit initial asset is supported initially. Governance may later add standard
/// six-decimal ERC20 assets; rebasing/fee-on-transfer tokens are not supported.
contract ArcadiaFactory is AccessControl, ReentrancyGuard {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MARKET_CREATOR_ROLE = keccak256("MARKET_CREATOR_ROLE");
    address public immutable riskManager;
    address public immutable rateModel;
    address public immutable marketAdmin;
    address[] private _markets;
    mapping(address => address) public marketFor;
    mapping(address => bool) public isMarket;
    mapping(address => bool) public isSupportedAsset;

    error ZeroAddress();
    error InvalidContract();
    error InvalidAsset();
    error UnsupportedAsset();
    error MarketAlreadyExists();
    error AssetAlreadySupported();
    error InvalidReserveFactor();

    event AssetSupported(address indexed asset);
    event AssetRemoved(address indexed asset);
    event MarketCreated(address indexed asset, address indexed market, address indexed creator, uint256 reserveFactor, uint256 index);

    /// @notice Grant roles, register initialAsset, and create its first pool atomically.
    /// @dev All created pools are administered by admin, never by the shared deployment wallet or factory.
    constructor(address admin, address riskManager_, address rateModel_, address initialAsset, uint256 reserveFactorWad) {
        if (admin == address(0) || riskManager_ == address(0) || rateModel_ == address(0)) revert ZeroAddress();
        if (riskManager_.code.length == 0 || rateModel_.code.length == 0) revert InvalidContract();
        marketAdmin = admin;
        riskManager = riskManager_;
        rateModel = rateModel_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(MARKET_CREATOR_ROLE, admin);
        _addSupportedAsset(initialAsset);
        _createMarket(initialAsset, reserveFactorWad, admin);
    }

    /// @notice Support a contract with readable six-decimal ERC20 metadata. Admin must vet token behavior.
    function addSupportedAsset(address asset) external onlyRole(ADMIN_ROLE) {
        _addSupportedAsset(asset);
    }

    /// @notice Remove support for future creation; existing pool registration and user exits are unaffected.
    function removeSupportedAsset(address asset) external onlyRole(ADMIN_ROLE) {
        if (asset == address(0)) revert ZeroAddress();
        if (!isSupportedAsset[asset]) revert UnsupportedAsset();
        isSupportedAsset[asset] = false;
        emit AssetRemoved(asset);
    }

    /// @notice Create the sole pool for a supported asset, with the constructor-selected explicit pool admin.
    function createMarket(address asset, uint256 reserveFactor) external onlyRole(MARKET_CREATOR_ROLE) nonReentrant returns (address market) {
        return _createMarket(asset, reserveFactor, msg.sender);
    }

    /// @notice Return every market in creation order, including the constructor-created pool.
    function allMarkets() external view returns (address[] memory) {
        return _markets;
    }

    /// @notice Number of registered markets.
    function marketsLength() external view returns (uint256) {
        return _markets.length;
    }

    function _addSupportedAsset(address asset) private {
        if (asset == address(0)) revert ZeroAddress();
        if (asset.code.length == 0) revert InvalidContract();
        if (isSupportedAsset[asset]) revert AssetAlreadySupported();
        try IERC20Metadata(asset).decimals() returns (uint8 assetDecimals) {
            if (assetDecimals != 6) revert InvalidAsset();
        } catch {
            revert InvalidAsset();
        }
        isSupportedAsset[asset] = true;
        emit AssetSupported(asset);
    }

    function _createMarket(address asset, uint256 reserveFactor, address creator) private returns (address market) {
        if (!isSupportedAsset[asset]) revert UnsupportedAsset();
        if (marketFor[asset] != address(0)) revert MarketAlreadyExists();
        if (reserveFactor > 0.5e18) revert InvalidReserveFactor();
        market = address(new LendingPool(asset, riskManager, rateModel, marketAdmin, reserveFactor));
        marketFor[asset] = market;
        isMarket[market] = true;
        uint256 index = _markets.length;
        _markets.push(market);
        emit MarketCreated(asset, market, creator, reserveFactor, index);
    }
}
