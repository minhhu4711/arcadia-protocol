import { useAccount } from 'wagmi'
import { useActivity } from '@/hooks/useActivity'

/** Confirmed ARCADIA events, optionally limited to the connected wallet. */
export function useTransactions(options: { mine?: boolean; limit?: number } = {}) {
  const { address } = useAccount()
  const q = useActivity()
  let items = q.data?.items ?? []
  if (options.mine) {
    items = address ? items.filter((i) => i.user.toLowerCase() === address.toLowerCase()) : []
  }
  if (options.limit) items = items.slice(0, options.limit)
  return {
    items,
    all: q.data?.items ?? [],
    fromBlock: q.data?.fromBlock,
    head: q.data?.head,
    isLoading: q.isLoading,
    error: q.error,
    refetch: q.refetch,
  }
}
