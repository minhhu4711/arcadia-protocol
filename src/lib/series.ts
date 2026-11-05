import type { ActivityItem } from '@/hooks/useActivity'

export interface TvlPoint {
  timestamp: number
  vault: number
  market: number
  total: number
}

export interface DailyFlow {
  day: string
  deposits: number
  withdrawals: number
}

const isInflow = (kind: ActivityItem['kind']) => kind === 'vault_deposit' || kind === 'pool_supply'

/**
 * Rebuilds net deposits over time from confirmed events (oldest to newest).
 * Accumulates in bigint, converts to Number only for chart display.
 */
export function buildTvlSeries(items: readonly ActivityItem[]): TvlPoint[] {
  const ordered = [...items].sort((a, b) => (a.block === b.block ? a.logIndex - b.logIndex : a.block < b.block ? -1 : 1))
  let vault = 0n
  let market = 0n
  return ordered.map((i) => {
    const delta = isInflow(i.kind) ? i.amount : -i.amount
    if (i.kind.startsWith('vault')) vault += delta
    else market += delta
    return { timestamp: i.timestamp, vault: Number(vault) / 1e6, market: Number(market) / 1e6, total: Number(vault + market) / 1e6 }
  })
}

export function buildDailyFlows(items: readonly ActivityItem[]): DailyFlow[] {
  const days = new Map<string, DailyFlow>()
  const ordered = [...items].sort((a, b) => a.timestamp - b.timestamp)
  for (const i of ordered) {
    const day = new Date(i.timestamp * 1000).toLocaleDateString('en-US', { month: 'short', day: 'numeric', timeZone: 'UTC' })
    const row = days.get(day) ?? { day, deposits: 0, withdrawals: 0 }
    if (isInflow(i.kind)) row.deposits += Number(i.amount) / 1e6
    else row.withdrawals += Number(i.amount) / 1e6
    days.set(day, row)
  }
  return [...days.values()]
}

export function totalsOf(items: readonly ActivityItem[]) {
  let deposits = 0n
  let withdrawals = 0n
  for (const i of items) {
    if (isInflow(i.kind)) deposits += i.amount
    else withdrawals += i.amount
  }
  return { deposits, withdrawals, count: items.length }
}
