import { erc20Abi, zeroAddress } from 'viem'
import { useAccount, useReadContract } from 'wagmi'
import { CHAIN_ID, USDC_ADDRESS } from '@/lib/deployments'

/** The connected wallet's USDC balance (ERC-20 view, 6 decimals). On Arc this is also the gas pool. */
export function useUSDCBalance() {
  const { address } = useAccount()
  const q = useReadContract({
    address: USDC_ADDRESS,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: [address ?? zeroAddress],
    chainId: CHAIN_ID,
    query: { enabled: Boolean(address), refetchInterval: 8_000 },
  })
  return { balance: q.data, isLoading: q.isLoading, error: q.error, refetch: q.refetch }
}
