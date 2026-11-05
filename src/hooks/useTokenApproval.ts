import { erc20Abi, zeroAddress, type Address } from 'viem'
import { useAccount, useReadContract } from 'wagmi'
import { approveCall } from '@/lib/calls'
import { CHAIN_ID, USDC_ADDRESS } from '@/lib/deployments'

/** USDC allowance granted to `spender`, plus the exact-amount approval call. */
export function useTokenApproval(spender: Address | undefined) {
  const { address } = useAccount()
  const q = useReadContract({
    address: USDC_ADDRESS,
    abi: erc20Abi,
    functionName: 'allowance',
    args: [address ?? zeroAddress, spender ?? zeroAddress],
    chainId: CHAIN_ID,
    query: { enabled: Boolean(address && spender), refetchInterval: 8_000 },
  })
  const allowance = q.data
  return {
    allowance,
    isLoading: q.isLoading,
    needsApproval: (amount: bigint) => allowance === undefined || allowance < amount,
    approveCall: (amount: bigint) => (spender ? approveCall(spender, amount) : undefined),
  }
}
