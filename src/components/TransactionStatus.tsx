import { CheckCircle2, ExternalLink, Loader2, XCircle } from 'lucide-react'
import type { ActionState } from '@/hooks/useAction'
import { CHAIN_ID } from '@/lib/deployments'
import { buildTxExplorerUrl } from '@/onchain-facts'

/** Shows only states the wallet and the chain have confirmed: signing, pending receipt, success, failure. */
export function TransactionStatus({ state }: { state: ActionState }) {
  if (state.status === 'idle') return null
  const link = state.hash && (
    <a className="inline-flex items-center gap-1 text-brand" href={buildTxExplorerUrl(CHAIN_ID, state.hash)} target="_blank" rel="noopener noreferrer">
      View transaction <ExternalLink size={11} />
    </a>
  )
  if (state.status === 'signing') {
    return (
      <p className="flex items-center gap-2 text-sm text-mute" role="status">
        <Loader2 size={15} className="animate-spin" /> Confirm &quot;{state.step}&quot; in your wallet.
      </p>
    )
  }
  if (state.status === 'confirming') {
    return (
      <p className="flex flex-wrap items-center gap-2 text-sm text-mute" role="status">
        <Loader2 size={15} className="animate-spin" /> Pending: waiting for the {state.step} receipt. {link}
      </p>
    )
  }
  if (state.status === 'success') {
    return (
      <p className="flex flex-wrap items-center gap-2 text-sm text-ok" role="status">
        <CheckCircle2 size={15} /> Confirmed onchain with a successful receipt. {link}
      </p>
    )
  }
  return (
    <p className="flex items-center gap-2 text-sm text-bad" role="alert">
      <XCircle size={15} /> {state.error}
    </p>
  )
}
