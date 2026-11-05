import type { MarketKind } from '@/lib/calls'
import { MoneyModal } from '@/components/MoneyModal'

/** Withdraw from the vault or the lending market. */
export function WithdrawModal({ kind, onClose }: { kind: MarketKind; onClose: () => void }) {
  return <MoneyModal kind={kind} mode="withdraw" onClose={onClose} />
}
