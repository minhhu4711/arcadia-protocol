import { Area, AreaChart, CartesianGrid, ReferenceLine, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts'

const WAD = 10n ** 18n

interface Params {
  base: bigint
  optimal: bigint
  slope1: bigint
  slope2: bigint
}

/** Mirrors InterestRateModel.getBorrowRate for display only (annual WAD rate). */
function borrowRateAt(util: bigint, p: Params): bigint {
  if (util <= p.optimal) return p.base + (util * p.slope1) / p.optimal
  return p.base + p.slope1 + ((util - p.optimal) * p.slope2) / (WAD - p.optimal)
}

const toPct = (wad: bigint) => Number(wad / 10n ** 12n) / 10_000

export function RateCurve({ params, current }: { params: Params; current: bigint }) {
  const data = Array.from({ length: 21 }, (_, i) => {
    const util = (WAD * BigInt(i * 5)) / 100n
    return { util: i * 5, rate: toPct(borrowRateAt(util, params)) }
  })
  const currentPct = Number(current / 10n ** 14n) / 100
  return (
    <div className="h-64 w-full">
      <ResponsiveContainer>
        <AreaChart data={data} margin={{ top: 8, right: 8, bottom: 0, left: -12 }}>
          <defs>
            <linearGradient id="rateFill" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#3185FF" stopOpacity={0.35} />
              <stop offset="100%" stopColor="#3185FF" stopOpacity={0} />
            </linearGradient>
          </defs>
          <CartesianGrid stroke="#24344F" strokeDasharray="3 3" vertical={false} />
          <XAxis dataKey="util" tickFormatter={(v: number) => `${v}%`} stroke="#9CAAC4" fontSize={11} tickLine={false} />
          <YAxis tickFormatter={(v: number) => `${v}%`} stroke="#9CAAC4" fontSize={11} tickLine={false} axisLine={false} />
          <Tooltip
            contentStyle={{ background: '#111C32', border: '1px solid #24344F', borderRadius: 10, fontSize: 12 }}
            formatter={(v) => [`${Number(v).toFixed(2)}%`, 'Borrow rate (APR)']}
            labelFormatter={(l) => `Utilization ${Number(l)}%`}
          />
          <ReferenceLine x={Number(params.optimal / 10n ** 16n)} stroke="#21C6B7" strokeDasharray="4 4" label={{ value: 'Optimal', fill: '#21C6B7', fontSize: 11, position: 'top' }} />
          <ReferenceLine x={Math.round(currentPct / 5) * 5} stroke="#F5B942" label={{ value: 'Now', fill: '#F5B942', fontSize: 11, position: 'insideTopRight' }} />
          <Area type="monotone" dataKey="rate" stroke="#3185FF" strokeWidth={2} fill="url(#rateFill)" />
        </AreaChart>
      </ResponsiveContainer>
    </div>
  )
}
