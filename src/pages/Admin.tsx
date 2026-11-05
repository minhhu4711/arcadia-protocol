import { useState } from 'react'
import { useAccount, useReadContracts, useWriteContract } from 'wagmi'
import { keccak256, toHex, zeroHash, type Address, type Hex } from 'viem'
import { Loader2, Lock } from 'lucide-react'
import { useProtocol } from '@/hooks/useProtocol'
import { useAction, type ActionStep } from '@/hooks/useAction'
import { ConfirmModal } from '@/components/ConfirmModal'
import { Badge, Card, EmptyState, PageHeader, Row, Skeleton } from '@/components/ui'
import { buildAddressExplorerUrl } from '@/onchain-facts'
import { NotDeployed } from '@/components/NotDeployed'
import { poolAbi, riskAbi, vaultAbi } from '@/lib/abis'
import { CHAIN_ID } from '@/lib/deployments'
import { fmtPctWad, fmtUsdc } from '@/lib/format'
import { parseUsdc } from '@/onchain-money'

const PAUSER = keccak256(toHex('PAUSER_ROLE'))
const RISK_ADMIN = keccak256(toHex('RISK_ADMIN_ROLE'))

interface Control {
  title: string
  body: string
  active: boolean
  activeLabel: string
  idleLabel: string
  allowed: boolean
  needs: string
  send: (next: boolean) => Promise<Hex>
}

function ControlRow({ c }: { c: Control }) {
  const [open, setOpen] = useState(false)
  const { run, busy } = useAction()
  const next = !c.active
  const step: ActionStep = { label: c.title, send: () => c.send(next) }
  return (
    <div className="flex flex-wrap items-center justify-between gap-3 py-4">
      <div className="min-w-0 flex-1">
        <div className="flex items-center gap-2 font-semibold">
          {c.title} {c.active ? <Badge tone="bad">{c.activeLabel}</Badge> : <Badge tone="ok">{c.idleLabel}</Badge>}
        </div>
        <p className="mt-1 text-sm text-mute">{c.body}</p>
        {!c.allowed && <p className="mt-1 flex items-center gap-1 text-xs text-warn"><Lock size={12} /> Requires {c.needs}</p>}
      </div>
      <button
        disabled={!c.allowed || busy}
        onClick={() => setOpen(true)}
        className="flex min-h-11 items-center gap-2 rounded-xl border border-line px-4 text-sm font-semibold hover:bg-panel disabled:cursor-not-allowed disabled:opacity-40"
      >
        {busy && <Loader2 size={14} className="animate-spin" />}
        {next ? 'Pause' : 'Resume'}
      </button>
      <ConfirmModal
        open={open}
        title={`${next ? 'Pause' : 'Resume'}: ${c.title}`}
        confirmLabel={next ? 'Pause' : 'Resume'}
        tone={next ? 'danger' : 'brand'}
        onCancel={() => setOpen(false)}
        onConfirm={() => {
          setOpen(false)
          void run([step], `${c.title} updated`)
        }}
      >
        <p>{c.body}</p>
        <p>This sends an onchain transaction from your wallet.</p>
      </ConfirmModal>
    </div>
  )
}

function LimitsForm({ allowed }: { allowed: boolean }) {
  const p = useProtocol()
  const { writeContractAsync } = useWriteContract()
  const { run, busy, state } = useAction()
  const d = p.risk?.vault
  const [vals, setVals] = useState({ cap: '', max: '', min: '', wd: '' })
  const [open, setOpen] = useState(false)

  let parsed: [bigint, bigint, bigint, bigint] | undefined
  let problem: string | undefined
  try {
    if (vals.cap && vals.max && vals.min) {
      const cap = parseUsdc(vals.cap)
      const max = parseUsdc(vals.max)
      const min = parseUsdc(vals.min)
      const wd = vals.wd ? parseUsdc(vals.wd) : 0n
      if (!(cap > 0n && min <= max && max <= cap)) problem = 'Require minimum <= per-transaction <= cap, with cap above zero.'
      else parsed = [cap, max, min, wd]
    }
  } catch {
    problem = 'Enter valid USDC amounts.'
  }

  const risk = p.addresses.risk
  const send = () => {
    if (!parsed || !risk) throw new Error('missing')
    return writeContractAsync({ address: risk, abi: riskAbi, functionName: 'setDefaults', args: parsed, chainId: CHAIN_ID })
  }

  const field = (key: keyof typeof vals, label: string, hint?: string) => (
    <label className="block text-sm">
      <span className="text-mute">{label}</span>
      <input
        value={vals[key]}
        inputMode="decimal"
        onChange={(e) => setVals({ ...vals, [key]: e.target.value.trim() })}
        placeholder={hint}
        className="num mt-1 min-h-11 w-full rounded-xl border border-line bg-panel px-3 outline-none focus:border-brand"
      />
    </label>
  )
  return (
    <div>
      <div className="grid gap-3 sm:grid-cols-2">
        {field('cap', 'Deposit cap (USDC)', d ? fmtUsdc(d.depositCap, 0) : '')}
        {field('max', 'Per-transaction deposit limit', d ? fmtUsdc(d.maxDepositPerTx, 0) : '')}
        {field('min', 'Minimum deposit', d ? fmtUsdc(d.minDeposit) : '')}
        {field('wd', 'Per-transaction withdrawal limit (empty = unlimited)', d ? fmtUsdc(d.maxWithdrawPerTx, 0) : '')}
      </div>
      {problem && <p className="mt-2 text-sm text-bad">{problem}</p>}
      {state.status === 'error' && <p className="mt-2 text-sm text-bad">{state.error}</p>}
      <button
        disabled={!allowed || !parsed || busy}
        onClick={() => setOpen(true)}
        className="mt-4 min-h-11 rounded-xl bg-brand px-5 text-sm font-semibold text-white disabled:cursor-not-allowed disabled:opacity-50"
      >
        Update default limits
      </button>
      {!allowed && <p className="mt-2 flex items-center gap-1 text-xs text-warn"><Lock size={12} /> Requires the risk admin role</p>}
      <ConfirmModal
        open={open}
        title="Update default risk limits"
        confirmLabel="Update"
        onCancel={() => setOpen(false)}
        onConfirm={() => {
          setOpen(false)
          void run([{ label: 'Update limits', send }], 'Default limits updated')
        }}
      >
        <p>New defaults apply to every market without its own override.</p>
      </ConfirmModal>
    </div>
  )
}

export default function Admin() {
  const p = useProtocol()
  const { address } = useAccount()
  const { writeContractAsync } = useWriteContract()
  const risk = p.addresses.risk
  const vault = p.addresses.vault
  const pool = p.addresses.pool
  const holder: Address = address ?? '0x0000000000000000000000000000000000000000'

  const roles = useReadContracts({
    allowFailure: false,
    contracts: [
      { address: risk ?? holder, abi: riskAbi, functionName: 'hasRole', args: [PAUSER, holder], chainId: CHAIN_ID },
      { address: risk ?? holder, abi: riskAbi, functionName: 'hasRole', args: [RISK_ADMIN, holder], chainId: CHAIN_ID },
      { address: risk ?? holder, abi: riskAbi, functionName: 'hasRole', args: [zeroHash, holder], chainId: CHAIN_ID },
      { address: vault ?? holder, abi: vaultAbi, functionName: 'hasRole', args: [PAUSER, holder], chainId: CHAIN_ID },
      { address: pool ?? holder, abi: poolAbi, functionName: 'hasRole', args: [PAUSER, holder], chainId: CHAIN_ID },
    ],
    query: { enabled: Boolean(address && risk && vault && pool), refetchInterval: 10_000 },
  })

  const subtitle = 'Role-gated protocol controls. Every action is an onchain transaction signed by your wallet.'
  if (!p.isDeployed) {
    return (
      <>
        <PageHeader title="Admin" subtitle={subtitle} />
        <NotDeployed />
      </>
    )
  }
  if (!address) {
    return (
      <>
        <PageHeader title="Admin" subtitle={subtitle} />
        <EmptyState title="Connect an admin wallet" body="Connect a wallet to see which roles it holds. Controls stay disabled without the matching role." />
      </>
    )
  }

  if (roles.isLoading || !risk || !vault || !pool || !p.risk || !p.vault || !p.pool) {
    return (
      <>
        <PageHeader title="Admin" subtitle={subtitle} />
        <Skeleton className="h-40 w-full" />
      </>
    )
  }
  const [riskPauser, riskAdmin, defaultAdmin, vaultPauser, poolPauser] = roles.data ?? [false, false, false, false, false]
  if (!(riskPauser || riskAdmin || defaultAdmin || vaultPauser || poolPauser)) {
    return (
      <>
        <PageHeader title="Admin" subtitle={subtitle} />
        <EmptyState title="Access restricted" body="This page is limited to wallets that hold an ARCADIA admin role. Connect an authorized administrator wallet to continue." />
      </>
    )
  }
  const addresses: Array<[string, Address | undefined]> = [
    ['Factory', p.addresses.factory],
    ['Risk manager', risk],
    ['Rate model', p.addresses.rateModel],
    ['Vault', vault],
    ['USDC market', pool],
  ]

  const controls: Control[] = [
    {
      title: 'Protocol',
      body: 'Pauses all deposits and withdrawals across every ARCADIA market.',
      active: p.risk.protocolPaused,
      activeLabel: 'Paused',
      idleLabel: 'Live',
      allowed: riskPauser,
      needs: 'the pauser role on the risk manager',
      send: (n) => writeContractAsync({ address: risk, abi: riskAbi, functionName: n ? 'pauseProtocol' : 'unpauseProtocol', chainId: CHAIN_ID }),
    },
    {
      title: 'Vault withdrawals',
      body: 'Blocks withdrawals from the USDC vault only. Deposits are unaffected.',
      active: p.risk.vault.withdrawalsPaused,
      activeLabel: 'Paused',
      idleLabel: 'Enabled',
      allowed: riskPauser,
      needs: 'the pauser role on the risk manager',
      send: (n) => writeContractAsync({ address: risk, abi: riskAbi, functionName: 'setWithdrawalsPaused', args: [vault, n], chainId: CHAIN_ID }),
    },
    {
      title: 'Market withdrawals',
      body: 'Blocks withdrawals from the USDC lending market only.',
      active: p.risk.pool.withdrawalsPaused,
      activeLabel: 'Paused',
      idleLabel: 'Enabled',
      allowed: riskPauser,
      needs: 'the pauser role on the risk manager',
      send: (n) => writeContractAsync({ address: risk, abi: riskAbi, functionName: 'setWithdrawalsPaused', args: [pool, n], chainId: CHAIN_ID }),
    },
    {
      title: 'Vault deposits',
      body: 'Stops new deposits into the vault. Existing holders can still withdraw.',
      active: p.vault.paused,
      activeLabel: 'Paused',
      idleLabel: 'Open',
      allowed: vaultPauser,
      needs: 'the pauser role on the vault',
      send: (n) => writeContractAsync({ address: vault, abi: vaultAbi, functionName: n ? 'pause' : 'unpause', chainId: CHAIN_ID }),
    },
    {
      title: 'Market supply',
      body: 'Stops new supply into the lending market. Existing lenders can still withdraw.',
      active: p.pool.paused,
      activeLabel: 'Paused',
      idleLabel: 'Open',
      allowed: poolPauser,
      needs: 'the pauser role on the market',
      send: (n) => writeContractAsync({ address: pool, abi: poolAbi, functionName: n ? 'pause' : 'unpause', chainId: CHAIN_ID }),
    },
  ]

  return (
    <>
      <PageHeader title="Admin" subtitle={subtitle} />
      <Card className="mb-4">
        <div className="display mb-1 text-lg font-semibold">Your roles</div>
        <div className="divide-y divide-line">
          <Row label="Risk manager: admin" value={defaultAdmin ? <Badge tone="ok">Held</Badge> : <Badge tone="mute">No</Badge>} />
          <Row label="Risk manager: risk admin" value={riskAdmin ? <Badge tone="ok">Held</Badge> : <Badge tone="mute">No</Badge>} />
          <Row label="Risk manager: pauser" value={riskPauser ? <Badge tone="ok">Held</Badge> : <Badge tone="mute">No</Badge>} />
          <Row label="Vault: pauser" value={vaultPauser ? <Badge tone="ok">Held</Badge> : <Badge tone="mute">No</Badge>} />
          <Row label="Market: pauser" value={poolPauser ? <Badge tone="ok">Held</Badge> : <Badge tone="mute">No</Badge>} />
        </div>
        {!riskPauser && !riskAdmin && !vaultPauser && !poolPauser && (
          <p className="mt-3 text-sm text-warn">This wallet holds no admin roles, so every control below is read-only.</p>
        )}
      </Card>
      <div className="mb-4 grid gap-4 md:grid-cols-2">
        <Card>
          <div className="display mb-1 text-lg font-semibold">Protocol configuration</div>
          <div className="divide-y divide-line">
            <Row label="Protocol state" value={p.risk.protocolPaused ? <Badge tone="bad">Paused</Badge> : <Badge tone="ok">Live</Badge>} />
            <Row label="Vault deposit cap" value={`${fmtUsdc(p.risk.vault.depositCap, 0)} USDC`} />
            <Row label="Market deposit cap" value={`${fmtUsdc(p.risk.pool.depositCap, 0)} USDC`} />
            <Row label="Per-transaction deposit limit" value={`${fmtUsdc(p.risk.vault.maxDepositPerTx, 0)} USDC`} />
            <Row label="Minimum deposit" value={`${fmtUsdc(p.risk.vault.minDeposit)} USDC`} />
            <Row label="Reserve factor" value={fmtPctWad(p.pool.reserveFactor)} />
          </div>
        </Card>
        <Card>
          <div className="display mb-1 text-lg font-semibold">Market status</div>
          <div className="divide-y divide-line">
            <Row label="Vault deposits" value={p.vault.paused ? <Badge tone="warn">Paused</Badge> : <Badge tone="ok">Open</Badge>} />
            <Row label="Vault withdrawals" value={p.risk.vault.withdrawalsPaused ? <Badge tone="warn">Paused</Badge> : <Badge tone="ok">Enabled</Badge>} />
            <Row label="Market supply" value={p.pool.paused ? <Badge tone="warn">Paused</Badge> : <Badge tone="ok">Open</Badge>} />
            <Row label="Market withdrawals" value={p.risk.pool.withdrawalsPaused ? <Badge tone="warn">Paused</Badge> : <Badge tone="ok">Enabled</Badge>} />
            <Row label="Utilization" value={fmtPctWad(p.pool.utilization)} />
          </div>
        </Card>
      </div>
      <Card className="mb-4">
        <div className="display mb-1 text-lg font-semibold">Contract addresses</div>
        <div className="divide-y divide-line">
          {addresses.map(([label, addr]) => (
            <Row
              key={label}
              label={label}
              value={addr ? <a className="mono text-xs text-brand" href={buildAddressExplorerUrl(CHAIN_ID, addr)} target="_blank" rel="noopener noreferrer">{addr}</a> : '--'}
            />
          ))}
        </div>
      </Card>
      <Card className="mb-4">
        <div className="display text-lg font-semibold">Emergency controls</div>
        <p className="mt-1 text-sm text-mute">Each action opens a confirmation, then asks your wallet to sign.</p>
        <div className="divide-y divide-line">{controls.map((c) => <ControlRow key={c.title} c={c} />)}</div>
      </Card>
      <Card>
        <div className="display mb-3 text-lg font-semibold">Default risk limits</div>
        <LimitsForm allowed={riskAdmin} />
      </Card>
    </>
  )
}
