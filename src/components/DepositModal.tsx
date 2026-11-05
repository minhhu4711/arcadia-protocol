import type { MarketKind } from '@/lib/calls'
import { MoneyModal } from '@/components/MoneyModal'

/** Deposit into the vault or supply to the lending market. */
export function DepositModal({ kind, onClose }: { kind: MarketKind; onClose: () => void }) {
  return <MoneyModal kind={kind} mode="deposit" onClose={onClose} />
}
