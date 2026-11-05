# ARCADIA

Where Capital Finds Its Flow. A USDC vault and lending market with a professional dashboard, built for Arc Testnet.

Built with [Arc Studio](https://studio.arc.io)

## What it does

- Overview of protocol liquidity, utilization and risk status
- USDC Vault: deposit and withdraw at a fixed 1 USDC per share (no yield source, so no APY is shown)
- Lending market: supply and withdraw USDC, with a utilization-based rate curve
- Portfolio, transaction history and analytics, all read from the chain
- Admin controls for pausing and risk limits, gated by onchain roles

Borrowing, collateral, liquidation and yield strategies are not live. Only interfaces for them exist in the contracts.

## Tech stack

- React 18, Vite, TypeScript, Tailwind CSS, Recharts, React Router
- Vitest and Testing Library for the web app
- wagmi, viem, ConnectKit
- Solidity 0.8.28, Foundry, OpenZeppelin 5.6.1

## Development

Prerequisites: Bun and Foundry.

```bash
bun install
bun run dev
```

Build and test the contracts:

```bash
bun run contracts:build
bun run contracts:test
```

Test the web app: `bun run test`

Lint and typecheck: `bun run check`

Build a container: see `docs/DEPLOYMENT.md`

### Environment variables

- `VITE_ARCADIA_FACTORY`: address of the deployed ArcadiaFactory (public)
- `VITE_ARCADIA_VAULT`: address of the deployed ArcadiaVault (public)
- `VITE_ARCADIA_DEPLOY_BLOCK`: block of deployment, where history scanning starts (public)

Without the first two, the app shows a "contracts not connected" state.

## Docs

See `PROJECT_STATUS.md` for progress, and `docs/` for the product requirements, architecture, contracts, database design, security notes and deployment.

The contracts have unit, fuzz and invariant tests but have not been audited by a third party. Use testnet funds only.
