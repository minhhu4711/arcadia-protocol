import { useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { Area, AreaChart, ResponsiveContainer, Tooltip } from 'recharts'
import { Badge, Card, ErrorState, PageHeader, Row, Skeleton, StatCard } from '@/components/ui'
import { NotDeployed } from '@/components/NotDeployed'
import { MarketCard } from '@/components/MarketCard'
import { TransactionHistory } from '@/components/TransactionHistory'
import { DepositModal } from '@/components/DepositModal'
import { WithdrawModal } from '@/components/WithdrawModal'
import { useLendingMarket } from '@/hooks/useLendingMarket'
import { usePortfolio } from '@/hooks/usePortfolio'
import { useTransactions } from '@/hooks/useTransactions'
import { useVault } from '@/hooks/useVault'
import { fmtPctWad, fmtUsdc } from '@/lib/format'
import { buildTvlSeries } from '@/lib/series'
import type { MarketKind, MoneyMode } from '@/lib/calls'

export default function Overview() {
  const vault = useVault()
  const market = useLendingMarket()
  const portfolio = usePortfolio()
  const tx = useTransactions()
  const [modal, setModal] = useState<{ kind: MarketKind; mode: MoneyMode } | null>(null)
  const series = useMemo(() => buildTvlSeries(tx.all), [tx.all])

  if (!vault.isDeployed) {
    return (
      <>
        <PageHeader title="Overview" subtitle="Protocol-wide liquidity, lending and risk status on Arc Testnet." />
        <NotDeployed />
      </>
    )
  }

  const pool = market.pool
  const loading = vault.isLoading || market.isLoading
  const tvl = vault.totalAssets !== undefined && pool ? vault.totalAssets + pool.supplied : undefined
  const paused = vault.protocolPaused
  const utilPct = pool ? Number(pool.utilization / 10n ** 14n) / 100 : 0

  return (
    <>
      <PageHeader
        title="Overview"
        subtitle="Protocol-wide liquidity, lending and risk status on Arc Testnet."
        right={paused === undefined ? null : paused ? <Badge tone="bad">Protocol paused</Badge> : <Badge tone="ok">Protocol live</Badge>}
      />
      {vault.error && <ErrorState message={vault.error.message.split('\n')[0]} onRetry={vault.refetch} />}

      <div className="grid gap-4 lg:grid-cols-3">
        <Card className="overflow-hidden">
          <div className="label">Total value locked</div>
          {loading ? <Skeleton className="mt-2 h-10 w-48" /> : <div className="display num mt-2 text-4xl font-semibold">${fmtUsdc(tvl)}</div>}
          <div className="mt-1 text-xs text-mute">Vault + lending market, read from the contracts</div>
          <div className="-mx-5 -mb-5 mt-3 h-24">
            {tx.isLoading ? (
              <Skeleton className="mx-5 h-20" />
            ) : series.length < 2 ? (
              <p className="px-5 pt-5 text-xs text-mute">History chart appears after two or more confirmed transactions.</p>
            ) : (
              <ResponsiveContainer>
                <AreaChart data={series} margin={{ top: 4, right: 0, bottom: 0, left: 0 }}>
                  <defs>
                    <linearGradient id="tvlFill" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="0%" stopColor="#3185FF" stopOpacity={0.4} />
                      <stop offset="100%" stopColor="#3185FF" stopOpacity={0} />
                    </linearGradient>
                  </defs>
                  <Tooltip
                    contentStyle={{ background: '#111C32', border: '1px solid #24344F', borderRadius: 10, fontSize: 12 }}
                    formatter={(v) => [`$${Number(v).toLocaleString('en-US', { maximumFractionDigits: 2 })}`, 'Net deposits']}
                    labelFormatter={() => ''}
                  />
                  <Area type="stepAfter" dataKey="total" stroke="#3185FF" strokeWidth={2} fill="url(#tvlFill)" />
                </AreaChart>
              </ResponsiveContainer>
            )}
          </div>
        </Card>

        <Card>
          <div className="label">Market liquidity</div>
          <div className="mt-2 grid grid-cols-3 gap-2">
            <div><div className="text-xs text-mute">Supplied</div><div className="display num mt-1 text-lg font-semibold">{loading ? '--' : `$${fmtUsdc(pool?.supplied, 0)}`}</div></div>
            <div><div className="text-xs text-mute">Borrowed</div><div className="display num mt-1 text-lg font-semibold">{loading ? '--' : `$${fmtUsdc(pool?.borrowed, 0)}`}</div></div>
            <div><div className="text-xs text-mute">Available</div><div className="display num mt-1 text-lg font-semibold">{loading ? '--' : `$${fmtUsdc(pool?.liquidity, 0)}`}</div></div>
          </div>
          <div className="mt-5">
            <div className="h-2 overflow-hidden rounded-full bg-line" role="progressbar" aria-valuenow={utilPct} aria-valuemin={0} aria-valuemax={100} aria-label="Utilization">
              <div className="h-full rounded-full bg-aqua" style={{ width: `${Math.min(100, utilPct)}%` }} />
            </div>
            <div className="mt-1.5 flex justify-between text-xs text-mute">
              <span>Utilization {fmtPctWad(pool?.utilization)}</span>
              <span>Borrowing not live</span>
            </div>
          </div>
        </Card>

        <Card>
          <div className="label">Your portfolio</div>
          {!portfolio.isConnected ? (
            <p className="mt-3 text-sm text-mute">Connect a wallet to see your USDC balance and positions.</p>
          ) : (
            <>
              {portfolio.isLoading ? <Skeleton className="mt-2 h-10 w-40" /> : <div className="display num mt-2 text-3xl font-semibold">${fmtUsdc(portfolio.total)}</div>}
              <div className="mt-2 divide-y divide-line">
                <Row label="Wallet USDC" value={fmtUsdc(portfolio.wallet)} />
                <Row label="In vault" value={fmtUsdc(portfolio.vaultAssets)} />
                <Row label="Supplied to market" value={fmtUsdc(portfolio.supplied)} />
              </div>
            </>
          )}
          <Link to="/portfolio" className="mt-3 inline-block text-sm text-brand">Open portfolio</Link>
        </Card>
      </div>

      <div className="mt-4 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard label="Protocol markets" loading={market.marketCount === undefined && loading} value={market.marketCount?.toString() ?? '--'} sub="USDC only in this release" />
        <StatCard label="Supply APR" loading={loading} accent="brand" value={fmtPctWad(pool?.supplyRate)} tip="Lenders are paid by borrowers. With borrowing disabled the supply rate is 0%." />
        <StatCard label="Vault deposits" loading={loading} value={`$${fmtUsdc(vault.totalAssets, 0)}`} sub="No yield source connected" />
        <StatCard label="Reserve factor" loading={loading} value={fmtPctWad(pool?.reserveFactor)} tip="Share of borrower interest kept by the protocol." />
      </div>

      <div className="mt-6 grid gap-4 lg:grid-cols-2">
        <Card>
          <div className="mb-3 flex items-center justify-between">
            <div className="display text-lg font-semibold">Protocol markets</div>
            <Link to="/markets" className="text-sm text-brand">All markets</Link>
          </div>
          {market.row ? <MarketCard row={market.row} /> : <Skeleton className="h-24 w-full" />}
          <div className="mt-3 flex gap-3">
            <button onClick={() => setModal({ kind: 'pool', mode: 'deposit' })} disabled={pool?.paused || paused} className="min-h-11 flex-1 rounded-xl bg-brand text-sm font-semibold text-white disabled:opacity-50">Supply</button>
            <button onClick={() => setModal({ kind: 'pool', mode: 'withdraw' })} className="min-h-11 flex-1 rounded-xl border border-line text-sm font-semibold hover:bg-panel">Withdraw</button>
          </div>
        </Card>
        <Card>
          <div className="display text-lg font-semibold">Borrowed</div>
          <p className="mt-2 text-sm text-mute">Borrowing, collateral and liquidations are not live in this release, so there are no borrow positions to show.</p>
          <Badge tone="mute">Not available</Badge>
        </Card>
      </div>

      <div className="mt-6">
        <div className="mb-3 flex items-center justify-between">
          <h2 className="display text-lg font-semibold">Recent transactions</h2>
          <Link to="/history" className="text-sm text-brand">View all</Link>
        </div>
        <TransactionHistory items={tx.items.slice(0, 5)} loading={tx.isLoading} error={tx.error} onRetry={() => void tx.refetch()} />
      </div>

      {modal?.mode === 'deposit' && <DepositModal kind={modal.kind} onClose={() => setModal(null)} />}
      {modal?.mode === 'withdraw' && <WithdrawModal kind={modal.kind} onClose={() => setModal(null)} />}
    </>
  )
}
