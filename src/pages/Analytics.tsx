import { useMemo } from 'react'
import { Area, AreaChart, Bar, BarChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts'
import { useActivity } from '@/hooks/useActivity'
import { useProtocol } from '@/hooks/useProtocol'
import { Card, EmptyState, PageHeader, Skeleton, StatCard } from '@/components/ui'
import { NotDeployed } from '@/components/NotDeployed'
import { RateCurve } from '@/components/RateCurve'
import { fmtPctWad, fmtUsdCompact } from '@/lib/format'
import { buildDailyFlows, buildTvlSeries, totalsOf } from '@/lib/series'

const tip = { background: '#111C32', border: '1px solid #24344F', borderRadius: 10, fontSize: 12 }
const usd = (n: number) => `$${n.toLocaleString('en-US', { maximumFractionDigits: 2 })}`

export default function Analytics() {
  const p = useProtocol()
  const { data, isLoading } = useActivity()
  const subtitle = 'Liquidity and activity reconstructed from onchain events.'

  const items = data?.items
  const tvl = useMemo(
    () =>
      buildTvlSeries(items ?? []).map((pt) => ({
        t: new Date(pt.timestamp * 1000).toLocaleString('en-US', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }),
        vault: pt.vault,
        market: pt.market,
      })),
    [items],
  )
  const volume = useMemo(() => buildDailyFlows(items ?? []), [items])
  const totals = useMemo(() => totalsOf(items ?? []), [items])

  if (!p.isDeployed) {
    return (
      <>
        <PageHeader title="Analytics" subtitle={subtitle} />
        <NotDeployed />
      </>
    )
  }

  return (
    <>
      <PageHeader title="Analytics" subtitle={subtitle} />
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard label="Lifetime deposits" loading={isLoading} value={fmtUsdCompact(totals.deposits)} />
        <StatCard label="Lifetime withdrawals" loading={isLoading} value={fmtUsdCompact(totals.withdrawals)} />
        <StatCard label="Transactions" loading={isLoading} value={totals.count.toString()} />
        <StatCard label="Utilization" loading={p.isLoading} accent="aqua" value={fmtPctWad(p.pool?.utilization)} />
      </div>

      <div className="mt-4 grid gap-4 lg:grid-cols-2">
        <Card>
          <div className="display mb-3 text-lg font-semibold">Liquidity over time</div>
          {isLoading ? <Skeleton className="h-64 w-full" /> : tvl.length === 0 ? (
            <EmptyState title="No activity yet" body="The chart fills in as deposits and withdrawals are confirmed." />
          ) : (
            <div className="h-64">
              <ResponsiveContainer>
                <AreaChart data={tvl} margin={{ top: 8, right: 8, left: -8, bottom: 0 }}>
                  <CartesianGrid stroke="#24344F" strokeDasharray="3 3" vertical={false} />
                  <XAxis dataKey="t" stroke="#9CAAC4" fontSize={10} tickLine={false} minTickGap={32} />
                  <YAxis stroke="#9CAAC4" fontSize={11} tickLine={false} axisLine={false} tickFormatter={(v: number) => usd(v)} />
                  <Tooltip contentStyle={tip} formatter={(v) => usd(Number(v))} />
                  <Area type="stepAfter" dataKey="vault" name="Vault" stackId="1" stroke="#3185FF" fill="#3185FF" fillOpacity={0.3} />
                  <Area type="stepAfter" dataKey="market" name="Market" stackId="1" stroke="#21C6B7" fill="#21C6B7" fillOpacity={0.3} />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          )}
        </Card>
        <Card>
          <div className="display mb-3 text-lg font-semibold">Daily flows</div>
          {isLoading ? <Skeleton className="h-64 w-full" /> : volume.length === 0 ? (
            <EmptyState title="No flows yet" body="Daily deposit and withdrawal volume appears here." />
          ) : (
            <div className="h-64">
              <ResponsiveContainer>
                <BarChart data={volume} margin={{ top: 8, right: 8, left: -8, bottom: 0 }}>
                  <CartesianGrid stroke="#24344F" strokeDasharray="3 3" vertical={false} />
                  <XAxis dataKey="day" stroke="#9CAAC4" fontSize={11} tickLine={false} />
                  <YAxis stroke="#9CAAC4" fontSize={11} tickLine={false} axisLine={false} tickFormatter={(v: number) => usd(v)} />
                  <Tooltip contentStyle={tip} formatter={(v) => usd(Number(v))} cursor={{ fill: '#15233B' }} />
                  <Bar dataKey="deposits" name="Deposits" fill="#20C997" radius={[4, 4, 0, 0]} />
                  <Bar dataKey="withdrawals" name="Withdrawals" fill="#F5B942" radius={[4, 4, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            </div>
          )}
        </Card>
      </div>

      <Card className="mt-4">
        <div className="display mb-1 text-lg font-semibold">Borrow rate curve</div>
        <p className="mb-3 text-sm text-mute">Annual borrow rate by utilization. The marker shows where the market is today.</p>
        {p.rateModel && p.pool ? <RateCurve params={p.rateModel} current={p.pool.utilization} /> : <Skeleton className="h-64 w-full" />}
      </Card>
      {data && <p className="mt-3 text-xs text-mute">Built from event logs in blocks {data.fromBlock.toString()} to {data.head.toString()}.</p>}
    </>
  )
}
