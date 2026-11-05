import { useCallback, useState } from 'react'
import { useAccount, usePublicClient, useSendTransaction, useSwitchChain } from 'wagmi'
import { useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'
import type { Hex } from 'viem'
import { CHAIN_ID } from '@/lib/deployments'
import { parseOnchainError } from '@/lib/format'
import type { Call } from '@/lib/calls'
import { revertMessage } from '@/lib/revert'

export interface ActionStep {
  label: string
  /** Sends the transaction and returns its hash. Build it with a typed writeContractAsync call. */
  send: () => Promise<Hex>
}

export type ActionStatus = 'idle' | 'signing' | 'confirming' | 'success' | 'error'

export interface ActionState {
  status: ActionStatus
  step?: string
  hash?: Hex
  error?: string
}

/** Runs one or more wallet transactions in order, waiting for a real receipt after each. */
export function useAction(onDone?: () => void) {
  const { chainId, address: account, connector } = useAccount()
  const { switchChainAsync } = useSwitchChain()
  const client = usePublicClient({ chainId: CHAIN_ID })
  const queryClient = useQueryClient()
  const { sendTransactionAsync } = useSendTransaction()
  const [state, setState] = useState<ActionState>({ status: 'idle' })

  type Eip1193 = { request?: (args: { method: string; params?: unknown[] }) => Promise<unknown> }

  /** Ask the wallet to grant this site access to accounts again. Returns the accounts it now allows. */
  const regrant = useCallback(async (): Promise<string[]> => {
    if (!connector) return []
    const provider = (await connector.getProvider()) as Eip1193
    if (!provider.request) return []
    try {
      await provider.request({ method: 'wallet_requestPermissions', params: [{ eth_accounts: {} }] })
    } catch {
      /* some wallets do not implement it; eth_requestAccounts below covers them */
    }
    return (await provider.request({ method: 'eth_requestAccounts' })) as string[]
  }, [connector])

  /**
   * The app can look connected while the wallet has not granted this site access to the account
   * (for example after a wallet restart or inside an embedded preview). Ask the wallet again before signing.
   */
  const ensureAuthorized = useCallback(async () => {
    if (!connector || !account) return
    const provider = (await connector.getProvider()) as Eip1193
    if (!provider.request) return
    const granted = (await provider.request({ method: 'eth_accounts' })) as string[]
    if (granted.some((a) => a.toLowerCase() === account.toLowerCase())) return
    const requested = await regrant()
    if (!requested.some((a) => a.toLowerCase() === account.toLowerCase())) {
      throw Object.assign(new Error('Your wallet did not authorize this account. Select the account you connected with and try again.'), { simulated: true })
    }
  }, [account, connector, regrant])

  const run = useCallback(
    async (steps: ActionStep[], successMessage: string) => {
      try {
        if (chainId !== CHAIN_ID) await switchChainAsync({ chainId: CHAIN_ID })
        await ensureAuthorized()
        for (const step of steps) {
          setState({ status: 'signing', step: step.label })
          const hash = await step.send()
          setState({ status: 'confirming', step: step.label, hash })
          const receipt = await client?.waitForTransactionReceipt({ hash })
          if (!receipt || receipt.status !== 'success') throw new Error('reverted')
        }
        setState((s) => ({ ...s, status: 'success', step: undefined }))
        toast.success(successMessage)
        await queryClient.invalidateQueries()
        onDone?.()
        return true
      } catch (err) {
        console.error('[arcadia] transaction failed', err)
        const message = (err as { simulated?: boolean }).simulated ? (err as Error).message : parseOnchainError(err)
        if (message === null) {
          setState({ status: 'idle' })
        } else {
          setState({ status: 'error', error: message })
          toast.error(message)
        }
        return false
      }
    },
    [chainId, client, ensureAuthorized, onDone, queryClient, switchChainAsync],
  )

  const runCalls = useCallback(
    (calls: Call[], successMessage: string) =>
      run(
        calls.map((c) => ({
          label: c.label,
          send: async () => {
            // Simulate against current chain state right before asking the wallet to sign.
            try {
              await client?.call({ account, to: c.to, data: c.data })
            } catch (err) {
              throw Object.assign(new Error(revertMessage(err)), { simulated: true })
            }
            // Hand the wallet explicit gas and fee values so it does not have to estimate them on Arc.
            let gas: bigint | undefined
            let maxFeePerGas: bigint | undefined
            let maxPriorityFeePerGas: bigint | undefined
            try {
              const [estimate, fees] = await Promise.all([
                client?.estimateGas({ account, to: c.to, data: c.data }),
                client?.estimateFeesPerGas(),
              ])
              if (estimate !== undefined) gas = (estimate * 130n) / 100n
              if (fees?.maxFeePerGas !== undefined) {
                maxFeePerGas = fees.maxFeePerGas
                maxPriorityFeePerGas = fees.maxPriorityFeePerGas
              }
            } catch {
              /* fall back to the wallet's own estimation */
            }
            const send = () =>
              maxFeePerGas !== undefined && maxPriorityFeePerGas !== undefined
                ? sendTransactionAsync({ to: c.to, data: c.data, chainId: CHAIN_ID, gas, maxFeePerGas, maxPriorityFeePerGas })
                : sendTransactionAsync({ to: c.to, data: c.data, chainId: CHAIN_ID, gas })
            try {
              return await send()
            } catch (err) {
              // Wallet error 4100 (unauthorized): re-grant site access once, then retry the same transaction.
              if (!/not been authorized|4100/.test(`${(err as { message?: string }).message ?? ''} ${(err as { code?: number }).code ?? ''}`)) throw err
              await regrant()
              return await send()
            }
          },
        })),
        successMessage,
      ),
    [account, client, regrant, run, sendTransactionAsync],
  )

  const reset = useCallback(() => setState({ status: 'idle' }), [])
  return { state, run, runCalls, reset, busy: state.status === 'signing' || state.status === 'confirming' }
}
