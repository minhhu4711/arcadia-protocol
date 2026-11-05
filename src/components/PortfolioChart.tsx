import { Cell, Pie, PieChart, ResponsiveContainer, Tooltip } from 'recharts'
import { fmtUsdc } from '@/lib/format'

const COLORS = ['#9CAAC4', '#3185FF', '#21C6B7']

/** Allocation of the wallet and ARCADIA positions. Values are USDC base units. */
export function PortfolioChart({ wallet, vault, market }: { wallet: bigint; vault: bigint; market: bigint }) {
  const data = [
    { name: 'Wallet', raw: wallet },
    { name: 'Vault', raw: vault },
    { name: 'Lending market', raw: market },
  ].filter((d) => d.raw > 0n)
  if (data.length === 0) return null
  const chart = data.map((d) => ({ name: d.name, value: Number(d.raw) / 1e6, raw: d.raw }))
  return (
    <div className="flex flex-wrap items-center gap-6">
      <div className="h-40 w-40">
        <ResponsiveContainer>
          <PieChart>
            <Pie data={chart} dataKey="value" innerRadius={44} outerRadius={70} stroke="none" paddingAngle={2}>
              {chart.map((d) => <Cell key={d.name} fill={COLORS[['Wallet', 'Vault', 'Lending market'].indexOf(d.name)]} />)}
            </Pie>
            <Tooltip contentStyle={{ background: '#111C32', border: '1px solid #24344F', borderRadius: 10, fontSize: 12 }} formatter={(v) => `$${Number(v).toLocaleString('en-US', { maximumFractionDigits: 2 })}`} />
          </PieChart>
        </ResponsiveContainer>
      </div>
      <ul className="space-y-2 text-sm">
        {chart.map((d) => (
          <li key={d.name} className="flex items-center gap-2">
            <span className="h-2.5 w-2.5 rounded-full" style={{ background: COLORS[['Wallet', 'Vault', 'Lending market'].indexOf(d.name)] }} />
            <span className="text-mute">{d.name}</span>
            <span className="num font-medium">${fmtUsdc(d.raw)}</span>
          </li>
        ))}
      </ul>
    </div>
  )
}
