import { useReadContract } from 'wagmi'
import { factoryAbi } from '@/lib/abis'
import { CHAIN_ID, FACTORY_ADDRESS } from '@/lib/deployments'
import { useProtocol } from '@/hooks/useProtocol'
import type { MarketRow } from '@/lib/markets'

/** The USDC lending market state and the connected wallet's supplied balance. */
export function useLendingMarket() {
  const p = useProtocol()
  const count = useReadContract({
    address: FACTORY_ADDRESS,
    abi: factoryAbi,
    functionName: 'marketsLength',
    chainId: CHAIN_ID,
    query: { enabled: Boolean(FACTORY_ADDRESS), refetchInterval: 30_000 },
  })
  const pool = p.pool
  const row: MarketRow | undefined = pool && p.addresses.pool
    ? {
        id: p.addresses.pool,
        name: 'USDC Lending Market',
        asset: 'USDC',
        supplyRate: pool.supplyRate,
        // Borrowing has no public entry point yet, so no borrow rate is offered.
        borrowRate: undefined,
        supplied: pool.supplied,
        liquidity: pool.liquidity,
        utilization: pool.utilization,
        paused: pool.paused,
      }
    : undefined
  return {
    row,
    isDeployed: p.isDeployed,
    isLoading: p.isLoading,
    error: p.error,
    refetch: p.refetch,
    address: p.addresses.pool,
    marketCount: count.data,
    pool: p.pool,
    risk: p.risk?.pool,
    protocolPaused: p.risk?.protocolPaused,
    rateModel: p.rateModel,
    userSupplied: p.user?.poolAssets,
  }
}
