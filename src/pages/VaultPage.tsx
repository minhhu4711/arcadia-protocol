import { useState } from 'react'
import { PageHeader, Card } from '@/components/ui'
import { NotDeployed } from '@/components/NotDeployed'
import { VaultCard } from '@/components/VaultCard'
import { DepositModal } from '@/components/DepositModal'
import { WithdrawModal } from '@/components/WithdrawModal'
import { useVault } from '@/hooks/useVault'

export default function VaultPage() {
  const v = useVault()
  const [modal, setModal] = useState<'deposit' | 'withdraw' | null>(null)
  const subtitle = 'Deposit USDC and receive vault shares. Each share is redeemable for exactly 1 USDC.'
  if (!v.isDeployed) {
    return (
      <>
        <PageHeader title="USDC Vault" subtitle={subtitle} />
        <NotDeployed />
      </>
    )
  }
  return (
    <>
      <PageHeader title="USDC Vault" subtitle={subtitle} />
      <div className="grid gap-4 lg:grid-cols-5">
        <div className="lg:col-span-3">
          <VaultCard onDeposit={() => setModal('deposit')} onWithdraw={() => setModal('withdraw')} />
        </div>
        <div className="lg:col-span-2">
          <Card>
            <div className="display text-lg font-semibold">About this vault</div>
            <p className="mt-2 text-pretty text-sm leading-relaxed text-mute">
              The vault is an ERC-4626 compatible wrapper around USDC. It tracks deposits with internal accounting, so tokens sent to it directly do not change the share price.
              No yield source is connected, so no APY is advertised.
            </p>
            <p className="mt-3 text-pretty text-sm leading-relaxed text-mute">
              Every deposit or withdrawal is simulated against live chain state before your wallet is asked to sign, and is only reported as successful after a confirmed receipt.
            </p>
          </Card>
        </div>
      </div>
      {modal === 'deposit' && <DepositModal kind="vault" onClose={() => setModal(null)} />}
      {modal === 'withdraw' && <WithdrawModal kind="vault" onClose={() => setModal(null)} />}
    </>
  )
}
