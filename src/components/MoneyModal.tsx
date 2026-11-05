import { useState } from 'react'
import { ConnectKitButton } from 'connectkit'
import { Loader2, X } from 'lucide-react'
import { useAction } from '@/hooks/useAction'
import { useMoneyAction } from '@/hooks/useMoneyAction'
import { useWallet } from '@/hooks/useWallet'
import type { MarketKind, MoneyMode } from '@/lib/calls'
import { fmtUsdc } from '@/lib/format'
import { TokenAmountInput } from '@/components/TokenAmountInput'
import { TransactionStatus } from '@/components/TransactionStatus'

const NAMES: Record<MarketKind, string> = { vault: 'Arcadia USDC Vault', pool: 'USDC lending market' }

export function MoneyModal({ kind, mode, onClose }: { kind: MarketKind; mode: MoneyMode; onClose: () => void }) {
  const { isConnected, isWrongNetwork, switchToArc, switching } = useWallet()
  const [amountText, setAmountText] = useState('')
  const [review, setReview] = useState(false)
  const m = useMoneyAction(kind, mode, amountText)
  const { state, runCalls, reset, busy } = useAction(() => {
    setAmountText('')
    setReview(false)
  })

  const verb = mode === 'deposit' ? (kind === 'vault' ? 'Deposit' : 'Supply') : 'Withdraw'
  const sim = m.simulation
  const done = state.status === 'success'

  async function confirm() {
    await runCalls(m.calls, `${verb} confirmed`)
  }

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/60 p-4 sm:items-center" role="dialog" aria-modal="true" aria-label={`${verb} USDC`}>
      <div className="w-full max-w-md rounded-2xl border border-line bg-card p-6 shadow-2xl">
        <div className="mb-4 flex items-start justify-between">
          <div>
            <h2 className="display text-xl font-semibold">{verb} USDC</h2>
            <p className="text-sm text-mute">{NAMES[kind]}</p>
          </div>
          <button onClick={onClose} aria-label="Close" className="rounded-lg p-2 text-mute hover:bg-panel">
            <X size={18} />
          </button>
        </div>

        {!review ? (
          <>
            <TokenAmountInput
              value={amountText}
              onChange={(v) => {
                setAmountText(v)
                reset()
              }}
              balance={m.available}
              balanceLabel={mode === 'deposit' ? 'Wallet' : 'Deposited'}
            />
            {m.problem && <p className="mt-3 text-sm text-bad">{m.problem}</p>}
            {!m.problem && m.amount !== undefined && (
              <div className="mt-3 rounded-xl bg-panel p-3 text-sm" aria-live="polite">
                {sim.isFetching && (
                  <p className="flex items-center gap-2 text-mute"><Loader2 size={14} className="animate-spin" /> Simulating against live chain state...</p>
                )}
                {sim.status === 'error' && <p className="text-bad">Simulation failed: {sim.error}</p>}
                {sim.status === 'success' && sim.data && !sim.isFetching && (
                  <div className="space-y-1">
                    <p className="text-ok">Simulation passed.</p>
                    <div className="flex justify-between"><span className="text-mute">Estimated network fee</span><span className="num">~{fmtUsdc(sim.data.feeUsdc, 6)} USDC</span></div>
                    {sim.data.deferred && <p className="text-xs text-mute">The {verb.toLowerCase()} itself is simulated again right after the approval confirms.</p>}
                  </div>
                )}
              </div>
            )}
          </>
        ) : (
          <div className="space-y-2 rounded-xl bg-panel p-4 text-sm">
            <div className="flex justify-between"><span className="text-mute">Action</span><span>{verb}</span></div>
            <div className="flex justify-between"><span className="text-mute">Amount</span><span className="num font-semibold">{m.amount !== undefined ? fmtUsdc(m.amount, 6) : '--'} USDC</span></div>
            {kind === 'vault' && <div className="flex justify-between"><span className="text-mute">Share price</span><span>1 USDC per share</span></div>}
            <div className="flex justify-between"><span className="text-mute">Wallet steps</span><span>{m.calls.map((c) => c.label).join(', then ')}</span></div>
            {sim.data && <div className="flex justify-between"><span className="text-mute">Network fee (USDC)</span><span className="num">~{fmtUsdc(sim.data.feeUsdc, 6)}</span></div>}
            <p className="pt-1 text-xs text-mute">Testnet software, not audited by a third party. Nothing is final until the receipt is confirmed.</p>
          </div>
        )}

        <div className="mt-4 min-h-6"><TransactionStatus state={state} /></div>

        <div className="mt-4 flex gap-3">
          {!isConnected ? (
            <ConnectKitButton.Custom>
              {({ show }) => <button onClick={show} className="min-h-12 flex-1 rounded-xl bg-brand text-sm font-semibold text-white">Connect wallet</button>}
            </ConnectKitButton.Custom>
          ) : isWrongNetwork ? (
            <button onClick={switchToArc} disabled={switching} className="min-h-12 flex-1 rounded-xl bg-warn text-sm font-semibold text-base">Switch to Arc Testnet</button>
          ) : done ? (
            <button onClick={onClose} className="min-h-12 flex-1 rounded-xl bg-brand text-sm font-semibold text-white">Done</button>
          ) : review ? (
            <>
              <button onClick={() => setReview(false)} disabled={busy} className="min-h-12 flex-1 rounded-xl border border-line text-sm font-medium disabled:opacity-50">Back</button>
              <button onClick={() => void confirm()} disabled={busy || !m.ready} className="flex min-h-12 flex-[2] items-center justify-center gap-2 rounded-xl bg-brand text-sm font-semibold text-white disabled:opacity-50">
                {busy && <Loader2 size={16} className="animate-spin" />}
                {busy ? 'Waiting...' : `Confirm ${verb.toLowerCase()}`}
              </button>
            </>
          ) : (
            <button onClick={() => setReview(true)} disabled={!m.ready} className="min-h-12 flex-1 rounded-xl bg-brand text-sm font-semibold text-white disabled:cursor-not-allowed disabled:opacity-50">
              Review {verb.toLowerCase()}
            </button>
          )}
        </div>
      </div>
    </div>
  )
}
