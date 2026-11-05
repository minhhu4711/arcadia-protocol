import { useProtocol } from '@/hooks/useProtocol'

/** Vault state and the connected wallet's position, derived from the shared protocol read. */
export function useVault() {
  const p = useProtocol()
  const risk = p.risk?.vault
  const totalAssets = p.vault?.totalAssets
  const headroom = risk && totalAssets !== undefined ? (risk.depositCap > totalAssets ? risk.depositCap - totalAssets : 0n) : undefined
  return {
    isDeployed: p.isDeployed,
    isLoading: p.isLoading,
    error: p.error,
    refetch: p.refetch,
    address: p.addresses.vault,
    totalAssets,
    totalShares: p.vault?.totalSupply,
    sharePrice: p.vault?.sharePrice,
    depositsPaused: p.vault?.paused,
    protocolPaused: p.risk?.protocolPaused,
    risk,
    headroom,
    userShares: p.user?.vaultShares,
    userAssets: p.user?.vaultAssets,
  }
}
