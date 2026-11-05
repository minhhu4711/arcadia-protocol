import { describe, expect, it } from 'vitest'
import type { ActivityItem } from '@/hooks/useActivity'
import { buildDailyFlows, buildTvlSeries, totalsOf } from '@/lib/series'

const item = (n: number, kind: ActivityItem['kind'], usdc: number, ts: number): ActivityItem => ({
  id: `${n}`,
  kind,
  user: '0x0000000000000000000000000000000000000001',
  amount: BigInt(usdc) * 10n ** 6n,
  shares: 0n,
  hash: `0x${n.toString(16).padStart(64, '0')}`,
  block: BigInt(n),
  logIndex: 0,
  timestamp: ts,
})

const items = [item(3, 'vault_withdraw', 20, 300), item(1, 'vault_deposit', 100, 100), item(2, 'pool_supply', 50, 200)]

describe('buildTvlSeries', () => {
  it('accumulates net deposits in block order', () => {
    const s = buildTvlSeries(items)
    expect(s.map((p) => p.total)).toEqual([100, 150, 130])
    expect(s[2]).toMatchObject({ vault: 80, market: 50 })
  })
  it('returns an empty series with no events', () => {
    expect(buildTvlSeries([])).toEqual([])
  })
})

describe('totals and flows', () => {
  it('sums inflows and outflows exactly', () => {
    expect(totalsOf(items)).toEqual({ deposits: 150_000_000n, withdrawals: 20_000_000n, count: 3 })
  })
  it('groups flows by day', () => {
    const flows = buildDailyFlows(items)
    expect(flows).toHaveLength(1)
    expect(flows[0]).toMatchObject({ deposits: 150, withdrawals: 20 })
  })
})
