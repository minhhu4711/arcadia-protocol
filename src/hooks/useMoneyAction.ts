import { useMemo } from 'react'
import { useQuery } from '@tanstack/react-query'
import { useAccount, usePublicClient } from 'wagmi'
import { revertMessage } from '@/lib/revert'
import { buildCalls, type MarketKind, type MoneyMode } from '@/lib/calls'
import { CHAIN_ID } from '@/lib/deployments'
import { fmtUsdc } from '@/lib/format'
import { parseUsdc, gasTokenDecimalsFor, gasTokenToUsdc, Amount } from '@/onchain-money'
import { useProtocol } from '@/hooks/useProtocol'
import { useTokenApproval } from '@/hooks/useTokenApproval'

export interface Simulation {
  /** Estimated network fee in USDC base units (Arc gas is paid in USDC). */
  feeUsdc: bigint
  /** Label of the call that was simulated. */
  simulated: string
  /** True when a later step could only be simulated after the approval confirms. */
  deferred: boolean
}

/**
 * Validation, call building and a pre-flight simulation for a deposit, supply or withdrawal.
 * The simulation runs against live chain state before the wallet is asked to sign anything.
 */
export function useMoneyAction(kind: MarketKind, mode: MoneyMode, amountText: string) {
  const { address: account } = useAccount()
  const client = usePublicClient({ chainId: CHAIN_ID })
  const p = useProtocol()

  const target = kind === 'vault' ? p.addresses.vault : p.addresses.pool
  const risk = kind === 'vault' ? p.risk?.vault : p.risk?.pool
  const localPaused = kind === 'vault' ? p.vault?.paused : p.pool?.paused
  const totalAssets = kind === 'vault' ? p.vault?.totalAssets : p.pool?.supplied
  const position = kind === 'vault' ? p.user?.vaultAssets : p.user?.poolAssets
  const approval = useTokenApproval(target)

  const parsed = useMemo(() => {
    if (!amountText) return { value: undefined as bigint | undefined, error: undefined as string | undefined }
    try {
      const value = parseUsdc(amountText)
      return { value, error: value === 0n ? 'Enter an amount greater than zero.' : undefined }
    } catch {
      return { value: undefined, error: 'Enter a valid USDC amount (up to 6 decimals).' }
    }
  }, [amountText])

  const amount = parsed.value
  const available = mode === 'deposit' ? p.user?.usdc : position
  const isMax = amount !== undefined && position !== undefined && amount === position

  const problem = useMemo(() => {
    if (parsed.error) return parsed.error
    if (amount === undefined || !risk || !p.user) return undefined
    if (p.risk?.protocolPaused) return 'The protocol is paused.'
    if (mode === 'deposit') {
      if (localPaused) return 'Deposits are paused on this contract.'
      if (amount > p.user.usdc) return 'Amount exceeds your USDC balance.'
      if (amount < risk.minDeposit) return `Minimum deposit is ${fmtUsdc(risk.minDeposit)} USDC.`
      if (amount > risk.maxDepositPerTx) return `Per-transaction limit is ${fmtUsdc(risk.maxDepositPerTx)} USDC.`
      if (totalAssets !== undefined && totalAssets + amount > risk.depositCap) return 'This would exceed the deposit cap.'
    } else {
      if (risk.withdrawalsPaused) return 'Withdrawals are paused by risk controls.'
      if (position !== undefined && amount > position) return 'Amount exceeds your deposited balance.'
      if (risk.maxWithdrawPerTx > 0n && amount > risk.maxWithdrawPerTx) return `Per-transaction limit is ${fmtUsdc(risk.maxWithdrawPerTx)} USDC.`
      if (kind === 'pool' && p.pool && amount > p.pool.liquidity) return `Only ${fmtUsdc(p.pool.liquidity)} USDC of liquidity is available.`
    }
    return undefined
  }, [parsed.error, amount, risk, p.user, p.risk?.protocolPaused, p.pool, mode, localPaused, totalAssets, position, kind])

  const calls = useMemo(() => {
    if (amount === undefined || !target || !account || approval.allowance === undefined) return []
    return buildCalls(
      { kind, mode, target, account, amount, isMax, vaultShares: p.user?.vaultShares ?? 0n },
      approval.allowance,
    )
  }, [amount, target, account, approval.allowance, kind, mode, isMax, p.user?.vaultShares])

  const needsApproval = calls.length > 1

  const simulation = useQuery({
    queryKey: ['simulate', kind, mode, account, amount?.toString(), calls[0]?.data],
    enabled: Boolean(client && account && amount !== undefined && !problem && calls.length > 0),
    staleTime: 5_000,
    retry: false,
    queryFn: async (): Promise<Simulation> => {
      if (!client || !account || calls.length === 0 || amount === undefined) throw new Error('not ready')
      const first = calls[0]
      try {
        await client.call({ account, to: first.to, data: first.data })
        const [gas, gasPrice] = await Promise.all([
          client.estimateGas({ account, to: first.to, data: first.data }),
          client.getGasPrice(),
        ])
        const native = Amount.fromRaw(gas * gasPrice, gasTokenDecimalsFor(CHAIN_ID))
        const feeUsdc = gasTokenToUsdc(CHAIN_ID, native, 'trunc').raw + 1n
        const balance = p.user?.usdc ?? 0n
        const spend = mode === 'deposit' && !needsApproval ? amount : 0n
        if (spend + feeUsdc > balance) {
          throw new Error('Insufficient USDC to cover the amount plus the network fee (gas is paid in USDC).')
        }
        return { feeUsdc, simulated: first.label, deferred: needsApproval }
      } catch (err) {
        if (err instanceof Error && err.message.startsWith('Insufficient USDC')) throw err
        throw new Error(revertMessage(err))
      }
    },
  })

  return {
    target,
    risk,
    available,
    position,
    amount,
    isMax,
    problem,
    calls,
    needsApproval,
    simulation: {
      status: simulation.status,
      data: simulation.data,
      error: simulation.error?.message,
      isFetching: simulation.isFetching,
    },
    ready: Boolean(amount !== undefined && !problem && calls.length > 0 && simulation.status === 'success'),
  }
}
