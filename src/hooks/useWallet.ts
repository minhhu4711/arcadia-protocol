import { useAccount, useBalance, useDisconnect, useSwitchChain } from 'wagmi'
import { CHAIN_ID } from '@/lib/deployments'

/**
 * Wallet connection, network and gas state.
 * `nativeGasRaw` is the 18-decimal native view of the SAME USDC pool as the ERC-20 balance.
 * Use it only for fee checks, never display it next to the USDC balance.
 */
export function useWallet() {
  const { address, isConnected, isConnecting, chainId, connector } = useAccount()
  const { disconnect } = useDisconnect()
  const { switchChain, isPending: switching, error: switchError } = useSwitchChain()
  const native = useBalance({ address, chainId: CHAIN_ID, query: { enabled: Boolean(address), refetchInterval: 15_000 } })

  return {
    address,
    isConnected,
    isConnecting,
    chainId,
    connectorName: connector?.name,
    isWrongNetwork: isConnected && chainId !== CHAIN_ID,
    switchToArc: () => switchChain({ chainId: CHAIN_ID }),
    switching,
    switchError,
    disconnect,
    nativeGasRaw: native.data?.value,
  }
}
