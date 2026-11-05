import { Link } from 'react-router-dom'
import { ConnectKitButton } from 'connectkit'
import { useAccount } from 'wagmi'
import { Card, EmptyState, PageHeader, Row, Skeleton, StatCard } from '@/components/ui'
import { NotDeployed } from '@/components/NotDeployed'
import { PortfolioChart } from '@/components/PortfolioChart'
import { TransactionHistory } from '@/components/TransactionHistory'
import { usePortfolio } from '@/hooks/usePortfolio'
import { useProtocol } from '@/hooks/useProtocol'
import { useTransactions } from '@/hooks/useTransactions'
import { fmtUsdc, shortAddr } from '@/lib/format'

export default function Portfolio() {
  const { address, isConnected } = useAccount()
  const { isDeployed } = useProtocol()
  const pf = usePortfolio()
  const tx = useTransactions({ mine: true })
  const subtitle = 'Your wallet balance and positions across ARCADIA.'

  if (!isDeployed) {
    return (
      <>
        <PageHeader title="Portfolio" subtitle={subtitle} />
        <NotDeployed />
      </>
    )
  }
  if (!isConnected) {
    return (
      <>
        <PageHeader title="Portfolio" subtitle={subtitle} />
        <EmptyState
          title="Connect your wallet"
          body="Connect a wallet to see your USDC balance, vault shares and lending positions."
          action={
            <ConnectKitButton.Custom>
              {({ show }) => <button onClick={show} className="min-h-11 rounded-xl bg-brand px-5 text-sm font-semibold text-white">Connect wallet</button>}
            </ConnectKitButton.Custom>
          }
        />
      </>
    )
  }

  return (
    <>
      <PageHeader title="Portfolio" subtitle={`${subtitle} Wallet ${shortAddr(address)}.`} />
      <div className="grid gap-4 sm:grid-cols-3">
        <StatCard label="Wallet USDC" loading={pf.isLoading} value={`$${fmtUsdc(pf.wallet)}`} sub="Also your gas balance on Arc" tip="On Arc, USDC is the native gas token. This is one balance, not two." />
        <StatCard label="Position value" loading={pf.isLoading} accent="brand" value={`$${fmtUsdc(pf.deposited)}`} sub="Vault + lending market" />
        <StatCard label="Total in USDC" loading={pf.isLoading} accent="aqua" value={`$${fmtUsdc(pf.total)}`} />
      </div>

      {pf.isEmpty ? (
        <div className="mt-4">
          <EmptyState
            title="No positions yet"
            body="Deposit USDC into the vault or supply it to the lending market to start."
            action={
              <div className="flex gap-3">
                <Link to="/vault" className="rounded-xl bg-brand px-4 py-2.5 text-sm font-semibold text-white">Open vault</Link>
                <Link to="/markets" className="rounded-xl border border-line px-4 py-2.5 text-sm font-semibold">Open markets</Link>
              </div>
            }
          />
        </div>
      ) : (
        <>
          <div className="mt-4 grid gap-4 md:grid-cols-2">
            <Card>
              <div className="display text-lg font-semibold">USDC Vault</div>
              {pf.vaultAssets === undefined ? <Skeleton className="mt-3 h-20 w-full" /> : (
                <div className="mt-2 divide-y divide-line">
                  <Row label="Value" value={`${fmtUsdc(pf.vaultAssets)} USDC`} />
                  <Row label="Shares" value={`${fmtUsdc((pf.vaultShares ?? 0n) / 10n ** 6n)} aUSDC`} />
                  <Row label="Yield earned" value="None (no yield source)" />
                </div>
              )}
              <Link to="/vault" className="mt-3 inline-block text-sm text-brand">Manage</Link>
            </Card>
            <Card>
              <div className="display text-lg font-semibold">USDC Lending Market</div>
              {pf.supplied === undefined ? <Skeleton className="mt-3 h-20 w-full" /> : (
                <div className="mt-2 divide-y divide-line">
                  <Row label="Supplied" value={`${fmtUsdc(pf.supplied)} USDC`} />
                  <Row label="Borrowed" value="0.00 USDC" tip="Borrowing is not live in this release." />
                </div>
              )}
              <Link to="/markets" className="mt-3 inline-block text-sm text-brand">Manage</Link>
            </Card>
          </div>
          <Card className="mt-4">
            <div className="display mb-3 text-lg font-semibold">Allocation</div>
            <PortfolioChart wallet={pf.wallet ?? 0n} vault={pf.vaultAssets ?? 0n} market={pf.supplied ?? 0n} />
          </Card>
        </>
      )}

      <h2 className="display mb-3 mt-8 text-lg font-semibold">Your transactions</h2>
      <TransactionHistory
        items={tx.items}
        loading={tx.isLoading}
        error={tx.error}
        onRetry={() => void tx.refetch()}
        showAccount={false}
        emptyTitle="No transactions for this wallet"
        emptyBody="Your deposits, supplies and withdrawals appear here once confirmed."
      />
    </>
  )
}
