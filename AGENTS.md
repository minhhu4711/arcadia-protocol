# ARCADIA

> Built with Arc Studio

Project memory for future agents.

## What this app does

USDC vault + lending market dashboard on Arc Testnet (Vite + React). Contracts in `contracts/`, tests in `contracts/test/`.

## Tech stack

- React 18, Vite, TypeScript, Tailwind, Recharts, React Router
- wagmi v2, viem, ConnectKit
- Solidity 0.8.28, Foundry, OpenZeppelin 5.6.1
- Chain: Arc Testnet (5042002). USDC `0x3600000000000000000000000000000000000000` (6 decimals, also native gas)

## Key files

- `src/hooks/useProtocol.ts`: all live chain reads
- `src/hooks/useAction.ts`: sequential wallet txs with receipt waits
- `src/hooks/useActivity.ts`: event-log scan for History/Analytics
- `src/lib/deployments.ts`: contract addresses from `VITE_ARCADIA_*` env vars
- `contracts/*.sol`: RiskManager, InterestRateModel, LendingPool, ArcadiaVault, ArcadiaFactory

## Deployment constraints

Deploys come from a platform wallet that cannot send follow-up txs, so every constructor does full setup and takes an explicit `admin`.
Factory constructor creates the USDC market; the pool address is read via `factory.marketFor(USDC)`.

## Deployed addresses

Arc Testnet, admin 0x77B6...2182. Factory 0x3aeca60609e36f958e830c75caaf9746f32b76e7, Vault 0x08f3be286da8ba4d4638fa5472279f884b67584b, RiskManager 0x90c15d186710aa568f6e8a26ca139fe77498d93e, RateModel 0x374f162ebbf0ae43b4991b58555409a7a6f591d4, USDC market (via factory.marketFor) 0x057883a793d5984ee5912bd28aCA51D6b5Ef7F56. Params: cap 1,000,000 USDC, per-tx 100,000, min 1, rates base 2% optimal 80% slope1 4% slope2 75%, reserve factor 10%.

## Not built

NestJS API, Postgres/Prisma, indexer, points, borrowing/liquidation. See `docs/ARCHITECTURE.md`.

## Share links

- Use `buildShareLink()` from `src/lib/share.ts` for any link a user copies. Keep `installShareSync()` in `src/main.tsx`.
- Never put secrets in URL path or query.
