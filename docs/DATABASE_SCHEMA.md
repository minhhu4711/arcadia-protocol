# Database schema (design, implemented in Phase 4)

PostgreSQL with Prisma. All financial values are stored as `Decimal(78,0)` base units (no floats). The database mirrors the chain; it never decides ownership.

## Entities

- **User**: `id`, `walletAddress` (unique, lowercase), `createdAt`, `updatedAt`
- **Market**: `id`, `marketAddress` (unique), `assetAddress`, `assetSymbol`, `assetDecimals`, `totalSupply`, `totalBorrow`, `availableLiquidity`, `utilizationRate`, `supplyAPY`, `borrowAPY`, timestamps
- **Position**: `id`, `userId` -> User, `marketId` -> Market, `suppliedAmount`, `borrowedAmount`, `shares`, timestamps. Unique on (`userId`, `marketId`)
- **Transaction**: `id`, `userId`, `marketId`, `transactionHash`, `logIndex`, `blockNumber`, `transactionType`, `amount`, `assetSymbol`, `status`, `timestamp`. Unique on (`transactionHash`, `logIndex`)
- **Vault**: `id`, `contractAddress` (unique), `assetAddress`, `totalAssets`, `totalShares`, `sharePrice`, timestamps
- **Points**: `id`, `userId`, `points`, `activityType`, `transactionHash`, `createdAt`
- **IndexerCursor**: `id`, `contractAddress`, `lastBlock`, `lastBlockHash` (used for reorg detection)

## Indexes

`Transaction(userId, timestamp)`, `Transaction(marketId, blockNumber)`, `Position(userId)`, `Points(userId)`.

## Rules

- Idempotent writes: events upsert on (`transactionHash`, `logIndex`)
- Status comes from the verified receipt, never from the client
- Wallet addresses are validated and lowercased before any query
