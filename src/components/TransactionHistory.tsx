import { ExternalLink } from 'lucide-react'
import { Badge, Card, EmptyState, ErrorState, Skeleton } from '@/components/ui'
import type { ActivityItem, ActivityKind } from '@/hooks/useActivity'
import { CHAIN_ID } from '@/lib/deployments'
import { fmtUsdc, shortAddr, timeAgo } from '@/lib/format'
import { buildTxExplorerUrl } from '@/onchain-facts'

const LABEL: Record<ActivityKind, { text: string; tone: 'ok' | 'warn' | 'brand' }> = {
  vault_deposit: { text: 'Vault deposit', tone: 'ok' },
  vault_withdraw: { text: 'Vault withdraw', tone: 'warn' },
  pool_supply: { text: 'Market supply', tone: 'brand' },
  pool_withdraw: { text: 'Market withdraw', tone: 'warn' },
}

export function TransactionHistory({
  items,
  loading,
  error,
  onRetry,
  emptyTitle = 'No activity yet',
  emptyBody = 'Transactions appear here as soon as they are confirmed onchain.',
  showAccount = true,
}: {
  items: ActivityItem[]
  loading: boolean
  error?: Error | null
  onRetry?: () => void
  emptyTitle?: string
  emptyBody?: string
  showAccount?: boolean
}) {
  if (error) return <ErrorState message={error.message.split('\n')[0]} onRetry={onRetry} />
  if (loading) {
    return (
      <div className="space-y-2">
        {Array.from({ length: 4 }, (_, i) => <Skeleton key={i} className="h-12 w-full" />)}
      </div>
    )
  }
  if (items.length === 0) return <EmptyState title={emptyTitle} body={emptyBody} />
  return (
    <Card className="overflow-x-auto p-0">
      <table className="w-full min-w-[720px] text-sm">
        <thead>
          <tr className="label text-left">
            <th className="px-5 py-3 font-semibold">Type</th>
            {showAccount && <th className="px-5 py-3 font-semibold">Account</th>}
            <th className="px-5 py-3 text-right font-semibold">Amount</th>
            <th className="px-5 py-3 font-semibold">Transaction</th>
            <th className="px-5 py-3 text-right font-semibold">Time</th>
            <th className="px-5 py-3 text-right font-semibold">Status</th>
          </tr>
        </thead>
        <tbody>
          {items.map((i) => (
            <tr key={i.id} className="border-t border-line">
              <td className="px-5 py-3"><Badge tone={LABEL[i.kind].tone}>{LABEL[i.kind].text}</Badge></td>
              {showAccount && <td className="mono px-5 py-3 text-xs">{shortAddr(i.user)}</td>}
              <td className="num px-5 py-3 text-right font-medium">{fmtUsdc(i.amount)} USDC</td>
              <td className="mono px-5 py-3 text-xs text-mute">{shortAddr(i.hash)}</td>
              <td className="px-5 py-3 text-right text-mute" title={i.timestamp ? new Date(i.timestamp * 1000).toISOString() : undefined}>{i.timestamp ? timeAgo(i.timestamp) : '--'}</td>
              <td className="px-5 py-3 text-right">
                <a className="inline-flex items-center gap-1 text-brand" href={buildTxExplorerUrl(CHAIN_ID, i.hash)} target="_blank" rel="noopener noreferrer">
                  Confirmed <ExternalLink size={12} />
                </a>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </Card>
  )
}
