# ARCADIA project status

Last updated after Phase 1 and Phase 2.

## Phase checklist

| Phase | Status |
| --- | --- |
| 1. Foundation (docs, env, tooling, CI, Docker) | Done, except monorepo layout and NestJS tooling |
| 2. Frontend | Done for the MVP pages and wallet flows |
| 3. Smart contracts | Done and deployed to Arc Testnet |
| 4. Backend (NestJS, Prisma, migrations, endpoints) | Not started |
| 5. Indexer | Not started |
| 6. Integration (frontend to backend) | Frontend reads the chain directly; backend wiring pending |
| 7. Quality assurance | Partial: contract and unit tests pass; no Playwright, no backend tests |
| 8. Testnet deployment of backend, indexer, frontend | Contracts only |

## Tests

- Contracts: 201 Foundry tests passing (191 unit/fuzz, 10 invariants). Gas report: `forge test --gas-report`.
- Frontend: 32 Vitest tests passing (formatting, call building, revert decoding, series math, market table sort/filter, transaction states, modals).
- Not yet: Playwright end-to-end tests, React Testing Library tests of the wallet flows (they need a wallet mock), backend tests.

## Decisions

- Single Vite + React app on Bun instead of a Next.js pnpm monorepo, because that is what this workspace runs.
- Wallet layer is wagmi + ConnectKit.
- Wallet transactions are built once as calldata, simulated with `eth_call` against live state, then sent. A step is only reported successful after a successful receipt.
- Gas on Arc is USDC. The app shows one USDC balance and checks amount plus estimated fee against it.
- Rates are shown as APR from the rate model. Borrow APR and yield show "Unavailable" because borrowing and yield sources are not live.
- History and analytics are rebuilt from event logs until the indexer exists.

## Unresolved issues

- Playwright is not set up.
- A single market exists, so table sorting and filtering are only exercised on one row in the live app (tests cover multiple rows).
- Dust from fractional vault redemptions can stay locked (documented in `docs/SMART_CONTRACTS.md`).
- Contract source is not verified on the explorer.

## Security concerns

- No third-party audit. Automated review and Slither found no high-severity issues.
- The admin wallet holds every role; consider splitting roles across wallets or a multisig before any real use.
- Event-log scanning relies on the public RPC and may be slow for long histories.

## Next steps

1. Phase 4: NestJS API, Prisma schema from `docs/DATABASE_SCHEMA.md`, migrations, endpoints, Docker Compose with Postgres and Redis.
2. Phase 5: indexer with block cursor, retry, reorg detection and idempotent writes.
3. Phase 6: switch history and analytics to the API, keep onchain reads for balances.
4. Playwright flows against a forked chain or testnet wallet mock.
