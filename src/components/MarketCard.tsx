import { Link } from 'react-router-dom'
import { TokenUSDC } from '@web3icons/react'
import { ArrowRight } from 'lucide-react'
import { APYDisplay } from '@/components/APYDisplay'
import { Badge } from '@/components/ui'
import type { MarketRow } from '@/lib/markets'
import { fmtUsdc } from '@/lib/format'

/** Compact market summary, used on the overview and on small screens. */
export function MarketCard({ row }: { row: MarketRow }) {
  return (
    <Link to="/markets" className="group block rounded-xl border border-line bg-panel p-4 transition-colors hover:border-brand">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2.5 font-semibold">
          <TokenUSDC variant="branded" size={26} /> {row.name}
        </div>
        <div className="flex items-center gap-2">
          {row.paused ? <Badge tone="warn">Paused</Badge> : <Badge tone="ok">Open</Badge>}
          <ArrowRight size={15} className="text-mute group-hover:text-brand" />
        </div>
      </div>
      <dl className="mt-3 grid grid-cols-3 gap-2 text-sm">
        <div><dt className="label">Supplied</dt><dd className="num mt-1 font-medium">${fmtUsdc(row.supplied)}</dd></div>
        <div><dt className="label">Available</dt><dd className="num mt-1 font-medium">${fmtUsdc(row.liquidity)}</dd></div>
        <div><dt className="label">Supply APR</dt><dd className="mt-1 font-medium text-aqua"><APYDisplay wad={row.supplyRate} /></dd></div>
      </dl>
    </Link>
  )
}
