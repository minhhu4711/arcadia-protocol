import { TokenUSDC } from '@web3icons/react'
import { fmtUsdc } from '@/lib/format'
import { formatUsdc } from '@/onchain-money'

export function TokenAmountInput({
  value,
  onChange,
  balance,
  balanceLabel,
  disabled,
}: {
  value: string
  onChange: (next: string) => void
  /** USDC base units. Undefined while loading or when no wallet is connected. */
  balance: bigint | undefined
  balanceLabel: string
  disabled?: boolean
}) {
  return (
    <div className="rounded-xl border border-line bg-panel p-4">
      <div className="flex items-center justify-between text-xs text-mute">
        <span>Amount</span>
        <span className="num">
          {balanceLabel}: {balance === undefined ? '--' : fmtUsdc(balance)} USDC
        </span>
      </div>
      <div className="mt-2 flex items-center gap-3">
        <input
          inputMode="decimal"
          placeholder="0.00"
          value={value}
          disabled={disabled}
          onChange={(e) => onChange(e.target.value.trim())}
          aria-label="Amount in USDC"
          className="display num w-full min-w-0 bg-transparent text-3xl font-semibold outline-none placeholder:text-line disabled:opacity-60"
        />
        <button
          type="button"
          disabled={disabled || balance === undefined}
          onClick={() => balance !== undefined && onChange(formatUsdc(balance))}
          className="min-h-9 rounded-lg border border-line px-3 text-xs font-semibold text-brand hover:bg-card disabled:opacity-40"
        >
          Max
        </button>
        <div className="flex items-center gap-1.5 text-sm font-semibold">
          <TokenUSDC variant="branded" size={22} /> USDC
        </div>
      </div>
    </div>
  )
}
