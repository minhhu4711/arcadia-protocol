import { useQuery } from '@tanstack/react-query'
import { usePublicClient } from 'wagmi'
import type { Address, Hex } from 'viem'
import { poolAbi, vaultAbi } from '@/lib/abis'
import { CHAIN_ID, DEPLOY_BLOCK, VAULT_ADDRESS } from '@/lib/deployments'
import { useProtocol } from '@/hooks/useProtocol'

export type ActivityKind = 'vault_deposit' | 'vault_withdraw' | 'pool_supply' | 'pool_withdraw'

export interface ActivityItem {
  id: string
  kind: ActivityKind
  user: Address
  amount: bigint
  shares: bigint
  hash: Hex
  block: bigint
  logIndex: number
  timestamp: number
}

const CHUNK = 5_000n
const MAX_CHUNKS = 400
const FALLBACK_LOOKBACK = 100_000n

const vaultEvents = vaultAbi.filter((i) => i.type === 'event')
const poolEvents = poolAbi.filter((i) => i.type === 'event' && (i.name === 'Supply' || i.name === 'Withdraw'))

/**
 * Reads Arcadia events straight from chain logs (the chain is the source of truth).
 * Scans forward from the deployment block in bounded ranges.
 */
export function useActivity() {
  const client = usePublicClient({ chainId: CHAIN_ID })
  const { addresses } = useProtocol()
  const pool = addresses.pool

  return useQuery({
    queryKey: ['arcadia-activity', VAULT_ADDRESS, pool],
    enabled: Boolean(client && VAULT_ADDRESS && pool),
    refetchInterval: 20_000,
    queryFn: async (): Promise<{ items: ActivityItem[]; fromBlock: bigint; head: bigint }> => {
      if (!client || !VAULT_ADDRESS || !pool) return { items: [], fromBlock: 0n, head: 0n }
      const head = await client.getBlockNumber()
      const start = DEPLOY_BLOCK ?? (head > FALLBACK_LOOKBACK ? head - FALLBACK_LOOKBACK : 0n)

      const ranges: Array<[bigint, bigint]> = []
      for (let from = start; from <= head && ranges.length < MAX_CHUNKS; from += CHUNK) {
        const to = from + CHUNK - 1n > head ? head : from + CHUNK - 1n
        ranges.push([from, to])
      }

      const raw: ActivityItem[] = []
      for (let i = 0; i < ranges.length; i += 8) {
        const batch = ranges.slice(i, i + 8)
        const results = await Promise.all(
          batch.map(async ([fromBlock, toBlock]) => {
            const [vLogs, pLogs] = await Promise.all([
              client.getLogs({ address: VAULT_ADDRESS, events: vaultEvents, fromBlock, toBlock }),
              client.getLogs({ address: pool, events: poolEvents, fromBlock, toBlock }),
            ])
            return { vLogs, pLogs }
          }),
        )
        for (const { vLogs, pLogs } of results) {
          for (const log of vLogs) {
            if (log.blockNumber === null || log.transactionHash === null || log.logIndex === null) continue
            if (log.eventName === 'Deposit') {
              raw.push({ id: `${log.transactionHash}-${log.logIndex}`, kind: 'vault_deposit', user: log.args.owner as Address, amount: log.args.assets as bigint, shares: log.args.shares as bigint, hash: log.transactionHash, block: log.blockNumber, logIndex: log.logIndex, timestamp: 0 })
            } else if (log.eventName === 'Withdraw') {
              raw.push({ id: `${log.transactionHash}-${log.logIndex}`, kind: 'vault_withdraw', user: log.args.owner as Address, amount: log.args.assets as bigint, shares: log.args.shares as bigint, hash: log.transactionHash, block: log.blockNumber, logIndex: log.logIndex, timestamp: 0 })
            }
          }
          for (const log of pLogs) {
            if (log.blockNumber === null || log.transactionHash === null || log.logIndex === null) continue
            if (log.eventName === 'Supply') {
              raw.push({ id: `${log.transactionHash}-${log.logIndex}`, kind: 'pool_supply', user: log.args.onBehalfOf as Address, amount: log.args.amount as bigint, shares: log.args.shares as bigint, hash: log.transactionHash, block: log.blockNumber, logIndex: log.logIndex, timestamp: 0 })
            } else if (log.eventName === 'Withdraw') {
              raw.push({ id: `${log.transactionHash}-${log.logIndex}`, kind: 'pool_withdraw', user: log.args.user as Address, amount: log.args.amount as bigint, shares: log.args.shares as bigint, hash: log.transactionHash, block: log.blockNumber, logIndex: log.logIndex, timestamp: 0 })
            }
          }
        }
      }

      const blocks = [...new Set(raw.map((r) => r.block))]
      const stamps = new Map<bigint, number>()
      for (let i = 0; i < blocks.length; i += 20) {
        const slice = blocks.slice(i, i + 20)
        const fetched = await Promise.all(slice.map((blockNumber) => client.getBlock({ blockNumber })))
        fetched.forEach((b, idx) => stamps.set(slice[idx], Number(b.timestamp)))
      }
      const items = raw
        .map((r) => ({ ...r, timestamp: stamps.get(r.block) ?? 0 }))
        .sort((a, b) => (a.block === b.block ? b.logIndex - a.logIndex : a.block > b.block ? -1 : 1))
      return { items, fromBlock: start, head }
    },
  })
}
