import { useWallet } from '@/hooks/useWallet'
import { CHAIN } from '@/lib/deployments'

export function NetworkIndicator() {
  const { isConnected, isWrongNetwork, switchToArc, switching } = useWallet()
  if (isWrongNetwork) {
    return (
      <button
        onClick={switchToArc}
        disabled={switching}
        className="flex min-h-10 items-center gap-2 rounded-xl border border-warn/50 bg-warn/10 px-3 text-xs font-semibold text-warn"
      >
        <span className="h-2 w-2 rounded-full bg-warn" />
        {switching ? 'Switching...' : `Wrong network: switch to ${CHAIN.name}`}
      </button>
    )
  }
  return (
    <div className="hidden items-center gap-2 rounded-xl border border-line px-3 py-2 text-xs text-mute sm:flex">
      <span className={`h-2 w-2 rounded-full ${isConnected ? 'bg-ok' : 'bg-mute'}`} />
      {CHAIN.name}
    </div>
  )
}
