import { useState } from 'react'
import { clsx } from 'clsx'
import { PageHeader } from '@/components/ui'
import { NotDeployed } from '@/components/NotDeployed'
import { TransactionHistory } from '@/components/TransactionHistory'
import { useProtocol } from '@/hooks/useProtocol'
import { useTransactions } from '@/hooks/useTransactions'

export default function History() {
  const { isDeployed } = useProtocol()
  const [mine, setMine] = useState(false)
  const tx = useTransactions({ mine })
  const subtitle = 'Every deposit, supply and withdrawal, read from onchain event logs.'

  if (!isDeployed) {
    return (
      <>
        <PageHeader title="Transaction history" subtitle={subtitle} />
        <NotDeployed />
      </>
    )
  }
  return (
    <>
      <PageHeader
        title="Transaction history"
        subtitle={subtitle}
        right={
          <div className="flex gap-1 rounded-xl bg-panel p-1">
            {[false, true].map((m) => (
              <button key={String(m)} onClick={() => setMine(m)} className={clsx('min-h-10 rounded-lg px-4 text-sm font-semibold', mine === m ? 'bg-brand text-white' : 'text-mute')}>
                {m ? 'My activity' : 'All activity'}
              </button>
            ))}
          </div>
        }
      />
      <TransactionHistory
        items={tx.items}
        loading={tx.isLoading}
        error={tx.error}
        onRetry={() => void tx.refetch()}
        emptyTitle={mine ? 'No activity for your wallet' : 'No activity yet'}
      />
      {tx.head !== undefined && tx.fromBlock !== undefined && (
        <p className="mt-3 text-xs text-mute">Scanned blocks {tx.fromBlock.toString()} to {tx.head.toString()}. Only confirmed events are shown.</p>
      )}
    </>
  )
}
