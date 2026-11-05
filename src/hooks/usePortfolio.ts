import { useAccount } from 'wagmi'
import { useProtocol } from '@/hooks/useProtocol'

/** Wallet balance plus ARCADIA positions. Values are USDC base units (6 decimals). */
export function usePortfolio() {
  const { isConnected } = useAccount()
  const p = useProtocol()
  const u = p.user
  const deposited = u ? u.vaultAssets + u.poolAssets : undefined
  return {
    isConnected,
    isLoading: isConnected && !u,
    wallet: u?.usdc,
    vaultAssets: u?.vaultAssets,
    vaultShares: u?.vaultShares,
    supplied: u?.poolAssets,
    deposited,
    total: u && deposited !== undefined ? u.usdc + deposited : undefined,
    isEmpty: u !== undefined && u.vaultAssets === 0n && u.poolAssets === 0n,
  }
}
