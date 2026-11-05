export interface MarketRow {
  id: string
  name: string
  asset: string
  supplyRate: bigint
  /** Borrow rates are shown only while borrowing is live. */
  borrowRate: bigint | undefined
  supplied: bigint
  liquidity: bigint
  utilization: bigint
  paused: boolean
}
