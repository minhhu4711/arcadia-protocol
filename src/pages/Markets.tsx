import { useMemo, useState } from 'react'
import { Badge, Card, ErrorState, PageHeader, Row, Skeleton } from '@/components/ui'
import { NotDeployed } from '@/components/NotDeployed'
import { MarketTable } from '@/components/MarketTable'
import { RateCurve } from '@/components/RateCurve'
import { DepositModal } from '@/components/DepositModal'
import { WithdrawModal } from '@/components/WithdrawModal'
import { useLendingMarket } from '@/hooks/useLendingMarket'
import { fmtPctWad } from '@/lib/format'

export default function Markets() {
  const m = useLendingMarket()
  const [modal, setModal] = useState<'deposit' | 'withdraw' | null>(null)
  const rows = useMemo(() => (m.row ? [m.row] : []), [m.row])
  const subtitle = 'Supply USDC to the lending market. Rates follow a utilization-based curve.'

  if (!m.isDeployed) {
    return (
      <>
        <PageHeader title="Lending markets" subtitle={subtitle} />
        <NotDeployed />
      </>
    )
  }
  const pool = m.pool
  const utilPct = pool ? Number(pool.utilization / 10n ** 14n) / 100 : 0
  return (
    <>
      <PageHeader title="Lending markets" subtitle={subtitle} />
      {m.error && <ErrorState message={m.error.message.split('\n')[0]} onRetry={m.refetch} />}
      <MarketTable rows={rows} loading={m.isLoading} onSupply={() => setModal('deposit')} onWithdraw={() => setModal('withdraw')} />
      <p className="mt-2 text-xs text-mute">Borrowing is not live in this release. Supply rates stay at 0% until borrowers exist. Rates are annual (APR) and read from the rate model.</p>

      <Card className="mt-4">
        <div className="mb-3 flex items-center justify-between">
          <div className="display text-lg font-semibold">Interest rate model</div>
          <Badge tone="brand">Kink model</Badge>
        </div>
        {m.rateModel && pool ? <RateCurve params={m.rateModel} current={pool.utilization} /> : <Skeleton className="h-64 w-full" />}
        <div className="mt-2 divide-y divide-line">
          <Row label="Base rate" value={fmtPctWad(m.rateModel?.base)} />
          <Row label="Optimal utilization" value={fmtPctWad(m.rateModel?.optimal)} tip="Above this level the borrow rate rises steeply to attract repayments and new supply." />
          <Row label="Slope below optimal" value={fmtPctWad(m.rateModel?.slope1)} />
          <Row label="Slope above optimal" value={fmtPctWad(m.rateModel?.slope2)} />
          <Row label="Current utilization" value={`${utilPct.toFixed(2)}%`} />
        </div>
      </Card>
      {modal === 'deposit' && <DepositModal kind="pool" onClose={() => setModal(null)} />}
      {modal === 'withdraw' && <WithdrawModal kind="pool" onClose={() => setModal(null)} />}
    </>
  )
}
