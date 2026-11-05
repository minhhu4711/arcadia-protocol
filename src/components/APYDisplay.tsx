import { InfoTip } from '@/components/ui'
import { fmtPctWad } from '@/lib/format'

/**
 * Shows a rate read from the contract, or "Unavailable" with the reason.
 * Rates are annual percentage rates from the rate model; no yield is estimated or invented.
 */
export function APYDisplay({ wad, unavailableReason, className }: { wad: bigint | undefined; unavailableReason?: string; className?: string }) {
  if (unavailableReason) {
    return (
      <span className={`inline-flex items-center gap-1 text-mute ${className ?? ''}`}>
        Unavailable <InfoTip text={unavailableReason} />
      </span>
    )
  }
  return <span className={`num ${className ?? ''}`}>{fmtPctWad(wad)}</span>
}
