# Product requirements: ARCADIA

Tagline: Where Capital Finds Its Flow.

## Goal

A professional DeFi interface and set of contracts for supplying USDC, managing liquidity and monitoring positions on Arc Testnet.

## Users

- Lenders and depositors who want a clear view of balances, rates and risk
- Protocol administrators who pause markets and set risk limits

## MVP scope

| Module | Status |
| --- | --- |
| Dashboard | Built |
| Wallet integration | Built |
| USDC vault (no yield source) | Built |
| Lending markets (supply side) | Built |
| Portfolio | Built |
| Transaction history | Built (from onchain logs) |
| Analytics | Built (from onchain logs) |
| Admin dashboard | Built |
| Backend API + database | Planned (Phase 4) |
| Indexer | Planned (Phase 5) |

## Out of scope for the MVP

Borrowing, collateral, liquidation, multi-asset markets, yield strategies, swap, points and leaderboard. These are not shown as working features.

## Principles

- The chain is the source of truth for balances and ownership
- No fabricated metrics: missing data shows as unavailable
- No advertised yield without a real yield source
- Testnet only; no mainnet deployment
