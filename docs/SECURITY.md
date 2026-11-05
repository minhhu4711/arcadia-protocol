# Security notes

These contracts have NOT been audited by a third party. An automated review and Slither found no high-severity issues; the test suite passes. That is not a substitute for a professional audit. Use testnet funds only.

## Controls in place

- Reentrancy guards on fund-moving functions, checks-effects-interactions ordering
- SafeERC20 for every token transfer
- Role-based access control with explicit admin addresses, no zero-address admin
- Emergency pause at protocol, market and contract level
- Deposit caps, minimums and per-transaction limits
- Internal accounting so unsolicited token transfers cannot move prices or balances
- Rounding always favours the protocol

## Secrets

No private keys are stored in the repository. Deployment keys must come from environment variables or a keystore.

## Reporting

Treat any suspected vulnerability as private until fixed.
