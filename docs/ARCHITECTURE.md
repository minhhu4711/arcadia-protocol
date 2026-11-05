# Architecture

## Scope of this release

Built and working:

- Contracts: RiskManager, InterestRateModel, LendingPool, ArcadiaVault, ArcadiaFactory, plus interfaces for future modules
- Foundry tests: unit, fuzz and invariant suites in `contracts/test/`
- Web app: Overview, Vault, Markets, Portfolio, History, Analytics, Admin

Not built yet (planned, intentionally not faked):

- NestJS REST API, PostgreSQL/Prisma schema, Redis, WebSocket updates
- Standalone blockchain indexer with reorg handling
- Points and leaderboard
- Borrowing, collateral management, liquidation, strategies, swap

## Stack decisions

The project runs on Vite + React, not Next.js, and uses Bun instead of pnpm. The app is a single package rather than a monorepo. The wallet layer is wagmi + ConnectKit instead of RainbowKit.

## Data flow

The chain is the source of truth. The web app reads balances, pool state and risk settings directly from the contracts with wagmi, refreshing every few seconds. History and Analytics are rebuilt from event logs (Deposit, Withdraw, Supply) scanned forward from the deployment block in bounded ranges. A dedicated indexer with a database would replace this scan for long histories.

## Network facts

Chain ID, RPC, explorer and the USDC address come from `src/onchain-facts.ts`. USDC is Arc's native gas token and also an ERC-20 with 6 decimals; the app shows a single USDC balance from the ERC-20 view.

## Roles

All privileged roles are granted at deployment to the admin address passed to the constructors. Contracts need no follow-up setup transactions.

## Web app structure

- `src/hooks`: chain logic (`useProtocol`, `useWallet`, `useUSDCBalance`, `useTokenApproval`, `useVault`, `useLendingMarket`, `usePortfolio`, `useTransactions`, `useMoneyAction`, `useAction`)
- `src/lib`: pure helpers (formatting, calldata building, revert decoding, chart series), all unit tested
- `src/components`: presentational components and the deposit/withdraw modals
- `src/pages`: one file per route

Deposits, supplies and withdrawals are built as calldata once, simulated with `eth_call` against current state, then sent. Success is reported only after a successful receipt.
