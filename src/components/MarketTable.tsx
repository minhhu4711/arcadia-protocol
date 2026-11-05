import { useMemo, useState } from 'react'
import { ArrowDown, ArrowUp, Search } from 'lucide-react'
import { TokenUSDC } from '@web3icons/react'
import { APYDisplay } from '@/components/APYDisplay'
import { Badge, Card, EmptyState, Skeleton } from '@/components/ui'
import { fmtUsdc } from '@/lib/format'
import type { MarketRow } from '@/lib/markets'

type SortKey = 'name' | 'supplyRate' | 'supplied' | 'liquidity' | 'utilization'

const COLUMNS: Array<{ key: SortKey; label: string; right?: boolean }> = [
  { key: 'name', label: 'Market' },
  { key: 'supplyRate', label: 'Supply APR', right: true },
  { key: 'supplied', label: 'Total supplied', right: true },
  { key: 'liquidity', label: 'Available', right: true },
  { key: 'utilization', label: 'Utilization', right: true },
]

export function MarketTable({
  rows,
  loading,
  onSupply,
  onWithdraw,
}: {
  rows: MarketRow[]
  loading: boolean
  onSupply: (id: string) => void
  onWithdraw: (id: string) => void
}) {
  const [query, setQuery] = useState('')
  const [status, setStatus] = useState<'all' | 'open' | 'paused'>('all')
  const [sort, setSort] = useState<{ key: SortKey; dir: 'asc' | 'desc' }>({ key: 'supplied', dir: 'desc' })

  const visible = useMemo(() => {
    const q = query.trim().toLowerCase()
    const filtered = rows.filter(
      (r) => (!q || r.name.toLowerCase().includes(q) || r.asset.toLowerCase().includes(q)) && (status === 'all' || (status === 'paused') === r.paused),
    )
    const dir = sort.dir === 'asc' ? 1 : -1
    return [...filtered].sort((a, b) => {
      const av = a[sort.key]
      const bv = b[sort.key]
      if (typeof av === 'string' && typeof bv === 'string') return av.localeCompare(bv) * dir
      return av === bv ? 0 : av > bv ? dir : -dir
    })
  }, [rows, query, status, sort])

  const toggle = (key: SortKey) => setSort((s) => (s.key === key ? { key, dir: s.dir === 'asc' ? 'desc' : 'asc' } : { key, dir: 'desc' }))

  return (
    <Card className="p-0">
      <div className="flex flex-wrap items-center gap-3 border-b border-line p-4">
        <label className="relative min-w-48 flex-1">
          <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-mute" />
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Filter by market or asset"
            aria-label="Filter markets"
            className="min-h-10 w-full rounded-xl border border-line bg-panel pl-9 pr-3 text-sm outline-none focus:border-brand"
          />
        </label>
        <select
          value={status}
          onChange={(e) => setStatus(e.target.value as typeof status)}
          aria-label="Filter by status"
          className="min-h-10 rounded-xl border border-line bg-panel px-3 text-sm outline-none"
        >
          <option value="all">All statuses</option>
          <option value="open">Supply open</option>
          <option value="paused">Supply paused</option>
        </select>
      </div>
      <div className="overflow-x-auto">
        <table className="w-full min-w-[820px] text-sm">
          <thead>
            <tr className="label text-left">
              {COLUMNS.map((c) => (
                <th key={c.key} className={`px-4 py-3 font-semibold ${c.right ? 'text-right' : ''}`} aria-sort={sort.key === c.key ? (sort.dir === 'asc' ? 'ascending' : 'descending') : 'none'}>
                  <button onClick={() => toggle(c.key)} className="inline-flex items-center gap-1 uppercase tracking-[0.08em]">
                    {c.label}
                    {sort.key === c.key && (sort.dir === 'asc' ? <ArrowUp size={12} /> : <ArrowDown size={12} />)}
                  </button>
                </th>
              ))}
              <th className="px-4 py-3 text-right font-semibold">Borrow APR</th>
              <th className="px-4 py-3" />
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={7} className="p-4"><Skeleton className="h-10 w-full" /></td>
              </tr>
            ) : visible.length === 0 ? (
              <tr>
                <td colSpan={7} className="p-4">
                  <EmptyState title="No markets match" body="Clear the filter to see every market." />
                </td>
              </tr>
            ) : (
              visible.map((r) => (
                <tr key={r.id} className="border-t border-line">
                  <td className="px-4 py-4">
                    <div className="flex items-center gap-2.5 font-semibold">
                      <TokenUSDC variant="branded" size={28} />
                      <div>
                        {r.name}
                        <div className="text-xs font-normal text-mute">{r.asset} {r.paused ? <Badge tone="warn">Supply paused</Badge> : null}</div>
                      </div>
                    </div>
                  </td>
                  <td className="px-4 py-4 text-right text-aqua"><APYDisplay wad={r.supplyRate} /></td>
                  <td className="num px-4 py-4 text-right">${fmtUsdc(r.supplied)}</td>
                  <td className="num px-4 py-4 text-right">${fmtUsdc(r.liquidity)}</td>
                  <td className="num px-4 py-4 text-right"><APYDisplay wad={r.utilization} /></td>
                  <td className="px-4 py-4 text-right">
                    <APYDisplay wad={r.borrowRate} unavailableReason={r.borrowRate === undefined ? 'Borrowing is not live in this release.' : undefined} />
                  </td>
                  <td className="px-4 py-4">
                    <div className="flex justify-end gap-2">
                      <button onClick={() => onSupply(r.id)} disabled={r.paused} className="min-h-10 rounded-lg bg-brand px-3 text-xs font-semibold text-white disabled:opacity-40">Supply</button>
                      <button onClick={() => onWithdraw(r.id)} className="min-h-10 rounded-lg border border-line px-3 text-xs font-semibold hover:bg-panel">Withdraw</button>
                    </div>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </Card>
  )
}
