# Smart contracts

All amounts are USDC base units (6 decimals). Rates are annual and expressed as WAD (1e18 = 100%).

| Contract | Purpose |
| --- | --- |
| `RiskManager` | Role-based deposit caps, per-transaction limits, minimums, protocol pause and per-market withdrawal pause. Defaults apply to every market unless overridden. |
| `InterestRateModel` | Immutable kink model: base + slope1 up to optimal utilization, then slope2. Interest accrues linearly in time: `borrows * rate * dt / (365 days * 1e18)`. |
| `LendingPool` | Share-based supply accounting for one asset. Uses internal accounting (never `balanceOf`) so stray transfers cannot change balances. Virtual shares guard against first-depositor inflation. Borrowing exists only as internal hooks; there is no public borrow function. |
| `ArcadiaVault` | ERC-4626 style USDC vault with a fixed 1 USDC per share price and no yield. Internal accounting ignores donated tokens. |
| `ArcadiaFactory` | Registers supported assets and creates lending markets. The USDC market is created in the constructor. |
| `interfaces/*` | `ICollateralManager`, `ILiquidationManager`, `IStrategyManager` describe future modules. They are not implemented. |

## Pausing behaviour

- Pool or vault pause blocks new deposits only. Withdrawals stay open.
- Protocol pause and per-market withdrawal pause (RiskManager) block withdrawals.
- A pool withdrawal is also limited by available liquidity.

## Tests

`bun run contracts:test` runs unit, fuzz and invariant tests (deposit/withdraw paths, access control, pausing, interest accrual, rounding, donations, fee-on-transfer tokens, factory rules).

## Known limits

- Assets must be standard ERC-20s: no rebasing, no transfer fees.
- Dust from fractional-share redemptions in the vault can remain locked.
- Borrowing is not live, so supply APR is 0% today.
