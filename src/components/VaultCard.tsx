import { TokenUSDC } from '@web3icons/react'
import { ExternalLink } from 'lucide-react'
import { Badge, Card, ErrorState, InfoTip, Row, Skeleton } from '@/components/ui'
import { useVault } from '@/hooks/useVault'
import { CHAIN_ID } from '@/lib/deployments'
import { fmtUsdc } from '@/lib/format'
import { buildAddressExplorerUrl } from '@/onchain-facts'

export function VaultCard({ onDeposit, onWithdraw }: { onDeposit: () => void; onWithdraw: () => void }) {
  const v = useVault()
  const closed = v.depositsPaused || v.protocolPaused
  return (
    <Card>
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <TokenUSDC variant="branded" size={36} />
          <div>
            <div className="display text-xl font-semibold">Arcadia USDC Vault</div>
            <div className="text-xs text-mute">ERC-4626 compatible · asset: USDC</div>
          </div>
        </div>
        {v.protocolPaused ? <Badge tone="bad">Protocol paused</Badge> : v.depositsPaused ? <Badge tone="warn">Deposits paused</Badge> : <Badge tone="ok">Open</Badge>}
      </div>

      {v.error && <div className="mt-4"><ErrorState message={v.error.message.split('\n')[0]} onRetry={v.refetch} /></div>}

      <div className="mt-5 grid gap-4 sm:grid-cols-2">
        <div>
          <div className="label">Total assets</div>
          {v.isLoading ? <Skeleton className="mt-2 h-9 w-44" /> : <div className="display num mt-1 text-3xl font-semibold">${fmtUsdc(v.totalAssets)}</div>}
        </div>
        <div>
          <div className="label">Your deposit</div>
          {v.userAssets === undefined ? <div className="display mt-1 text-3xl font-semibold text-mute">--</div> : <div className="display num mt-1 text-3xl font-semibold">${fmtUsdc(v.userAssets)}</div>}
          <div className="mt-1 text-xs text-mute">{v.userAssets === undefined ? 'Connect a wallet to see your deposit' : `${fmtUsdc((v.userShares ?? 0n) / 10n ** 6n)} aUSDC shares`}</div>
        </div>
      </div>

      <div className="mt-4 divide-y divide-line">
        <Row label="Share price" value={v.sharePrice === undefined ? '--' : `${fmtUsdc(v.sharePrice, 6)} USDC`} tip="Fixed at 1 USDC per share. The vault does not generate yield, so the price does not grow." />
        <Row
          label="Estimated yield"
          value={<span className="text-mute">Unavailable</span>}
          tip="No yield source is connected, so no yield is estimated or advertised."
        />
        <Row label="Remaining capacity" value={v.headroom === undefined ? '--' : `${fmtUsdc(v.headroom, 0)} USDC`} />
        <Row label="Minimum deposit" value={v.risk ? `${fmtUsdc(v.risk.minDeposit)} USDC` : '--'} />
        <Row label="Withdrawals" value={v.risk?.withdrawalsPaused || v.protocolPaused ? <Badge tone="bad">Paused</Badge> : <Badge tone="ok">Enabled</Badge>} />
      </div>

      <div className="mt-5 flex gap-3">
        <button onClick={onDeposit} disabled={closed} className="min-h-12 flex-1 rounded-xl bg-brand text-sm font-semibold text-white disabled:cursor-not-allowed disabled:opacity-50">Deposit</button>
        <button onClick={onWithdraw} className="min-h-12 flex-1 rounded-xl border border-line text-sm font-semibold hover:bg-panel">Withdraw</button>
      </div>
      {v.address && (
        <a className="mt-4 inline-flex items-center gap-1.5 text-sm text-brand" href={buildAddressExplorerUrl(CHAIN_ID, v.address)} target="_blank" rel="noopener noreferrer">
          View contract <ExternalLink size={13} /> <InfoTip text="Opens the vault contract on the Arc Testnet explorer." />
        </a>
      )}
    </Card>
  )
}
