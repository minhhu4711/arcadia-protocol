import { parseAbi } from 'viem'

export const vaultAbi = parseAbi([
  'function asset() view returns (address)',
  'function name() view returns (string)',
  'function symbol() view returns (string)',
  'function decimals() view returns (uint8)',
  'function totalAssets() view returns (uint256)',
  'function totalSupply() view returns (uint256)',
  'function balanceOf(address) view returns (uint256)',
  'function sharePrice() view returns (uint256)',
  'function paused() view returns (bool)',
  'function maxDeposit(address) view returns (uint256)',
  'function maxWithdraw(address) view returns (uint256)',
  'function convertToAssets(uint256) view returns (uint256)',
  'function previewDeposit(uint256) view returns (uint256)',
  'function deposit(uint256 assets, address receiver) returns (uint256)',
  'function withdraw(uint256 assets, address receiver, address owner) returns (uint256)',
  'function redeem(uint256 shares, address receiver, address owner) returns (uint256)',
  'function pause()',
  'function unpause()',
  'function hasRole(bytes32 role, address account) view returns (bool)',
  'function PAUSER_ROLE() view returns (bytes32)',
  'event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares)',
  'event Withdraw(address indexed sender, address indexed receiver, address indexed owner, uint256 assets, uint256 shares)',
])

export const poolAbi = parseAbi([
  'function totalSupplied() view returns (uint256)',
  'function totalBorrowed() view returns (uint256)',
  'function totalReserves() view returns (uint256)',
  'function availableLiquidity() view returns (uint256)',
  'function utilization() view returns (uint256)',
  'function borrowRate() view returns (uint256)',
  'function supplyRate() view returns (uint256)',
  'function reserveFactorWad() view returns (uint256)',
  'function balanceOf(address) view returns (uint256)',
  'function paused() view returns (bool)',
  'function supply(uint256 amount) returns (uint256)',
  'function withdraw(uint256 amount) returns (uint256)',
  'function withdrawAll() returns (uint256)',
  'function pause()',
  'function unpause()',
  'function hasRole(bytes32 role, address account) view returns (bool)',
  'function PAUSER_ROLE() view returns (bytes32)',
  'event Supply(address indexed user, address indexed onBehalfOf, uint256 amount, uint256 shares)',
  'event Withdraw(address indexed user, uint256 amount, uint256 shares)',
  'event InterestAccrued(uint256 interest, uint256 reserveCut, uint256 borrowRate, uint256 newTotalBorrowed, uint256 newTotalSupplied, uint256 timestamp)',
])

export const factoryAbi = parseAbi([
  'function marketFor(address asset) view returns (address)',
  'function marketsLength() view returns (uint256)',
  'function riskManager() view returns (address)',
  'function rateModel() view returns (address)',
  'function isSupportedAsset(address) view returns (bool)',
  'event MarketCreated(address indexed asset, address indexed market, address indexed creator, uint256 reserveFactor, uint256 index)',
])

export const riskAbi = parseAbi([
  'function protocolPaused() view returns (bool)',
  'function defaultDepositCap() view returns (uint256)',
  'function defaultMaxDepositPerTx() view returns (uint256)',
  'function defaultMinDeposit() view returns (uint256)',
  'function defaultMaxWithdrawPerTx() view returns (uint256)',
  'function getRisk(address market) view returns ((bool configured, uint256 depositCap, uint256 maxDepositPerTx, uint256 minDeposit, uint256 maxWithdrawPerTx, bool withdrawalsPaused))',
  'function hasRole(bytes32 role, address account) view returns (bool)',
  'function DEFAULT_ADMIN_ROLE() view returns (bytes32)',
  'function RISK_ADMIN_ROLE() view returns (bytes32)',
  'function PAUSER_ROLE() view returns (bytes32)',
  'function pauseProtocol()',
  'function unpauseProtocol()',
  'function setWithdrawalsPaused(address market, bool value)',
  'function setDefaults(uint256 cap, uint256 maxDeposit, uint256 minDeposit, uint256 maxWithdraw)',
  'function setMarketRisk(address market, uint256 cap, uint256 maxDeposit, uint256 minDeposit, uint256 maxWithdraw)',
  'function clearMarketRisk(address market)',
])

export const rateModelAbi = parseAbi([
  'function baseRate() view returns (uint256)',
  'function optimalUtilization() view returns (uint256)',
  'function slope1() view returns (uint256)',
  'function slope2() view returns (uint256)',
  'function getBorrowRate(uint256 utilizationWad) view returns (uint256)',
  'function getSupplyRate(uint256 utilizationWad, uint256 reserveFactorWad) view returns (uint256)',
])

/** Custom errors from the Arcadia contracts, used to decode simulation reverts. */
export const errorsAbi = parseAbi([
  'error ProtocolPaused()',
  'error BelowMinDeposit()',
  'error AboveMaxDepositPerTx()',
  'error DepositCapExceeded()',
  'error WithdrawalsPaused()',
  'error AboveMaxWithdrawPerTx()',
  'error InsufficientLiquidity()',
  'error InsufficientShares()',
  'error ZeroAmount()',
  'error EnforcedPause()',
  'error AccountingDeficit()',
])
