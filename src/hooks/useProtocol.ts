import { erc20Abi, zeroAddress, type Address } from 'viem'
import { useAccount, useReadContract, useReadContracts } from 'wagmi'
import { factoryAbi, poolAbi, rateModelAbi, riskAbi, vaultAbi } from '@/lib/abis'
import { CHAIN_ID, FACTORY_ADDRESS, USDC_ADDRESS, VAULT_ADDRESS } from '@/lib/deployments'

const REFRESH_MS = 8_000

export interface ProtocolState {
  isDeployed: boolean
  isLoading: boolean
  error: Error | null
  refetch: () => void
  addresses: { factory?: Address; vault?: Address; pool?: Address; risk?: Address; rateModel?: Address }
  pool?: {
    supplied: bigint
    borrowed: bigint
    reserves: bigint
    liquidity: bigint
    utilization: bigint
    borrowRate: bigint
    supplyRate: bigint
    reserveFactor: bigint
    paused: boolean
  }
  vault?: { totalAssets: bigint; totalSupply: bigint; sharePrice: bigint; paused: boolean }
  risk?: {
    protocolPaused: boolean
    vault: { depositCap: bigint; maxDepositPerTx: bigint; minDeposit: bigint; maxWithdrawPerTx: bigint; withdrawalsPaused: boolean }
    pool: { depositCap: bigint; maxDepositPerTx: bigint; minDeposit: bigint; maxWithdrawPerTx: bigint; withdrawalsPaused: boolean }
  }
  rateModel?: { base: bigint; optimal: bigint; slope1: bigint; slope2: bigint }
  user?: {
    usdc: bigint
    vaultAllowance: bigint
    poolAllowance: bigint
    vaultShares: bigint
    vaultAssets: bigint
    poolAssets: bigint
  }
}

/** One place that reads all live protocol and wallet state from chain. */
export function useProtocol(): ProtocolState {
  const { address: account } = useAccount()
  const enabled = Boolean(FACTORY_ADDRESS && VAULT_ADDRESS)

  const wiring = useReadContracts({
    allowFailure: false,
    contracts: [
      { address: FACTORY_ADDRESS ?? zeroAddress, abi: factoryAbi, functionName: 'marketFor', args: [USDC_ADDRESS], chainId: CHAIN_ID },
      { address: FACTORY_ADDRESS ?? zeroAddress, abi: factoryAbi, functionName: 'riskManager', chainId: CHAIN_ID },
      { address: FACTORY_ADDRESS ?? zeroAddress, abi: factoryAbi, functionName: 'rateModel', chainId: CHAIN_ID },
    ],
    query: { enabled, staleTime: 5 * 60_000 },
  })
  const [pool, risk, rateModel] = wiring.data ?? []
  const vault = VAULT_ADDRESS
  const ready = Boolean(pool && risk && rateModel && vault)
  const p = pool ?? zeroAddress
  const r = risk ?? zeroAddress
  const m = rateModel ?? zeroAddress
  const v = vault ?? zeroAddress

  const state = useReadContracts({
    allowFailure: false,
    contracts: [
      { address: p, abi: poolAbi, functionName: 'totalSupplied', chainId: CHAIN_ID },
      { address: p, abi: poolAbi, functionName: 'totalBorrowed', chainId: CHAIN_ID },
      { address: p, abi: poolAbi, functionName: 'totalReserves', chainId: CHAIN_ID },
      { address: p, abi: poolAbi, functionName: 'availableLiquidity', chainId: CHAIN_ID },
      { address: p, abi: poolAbi, functionName: 'utilization', chainId: CHAIN_ID },
      { address: p, abi: poolAbi, functionName: 'borrowRate', chainId: CHAIN_ID },
      { address: p, abi: poolAbi, functionName: 'supplyRate', chainId: CHAIN_ID },
      { address: p, abi: poolAbi, functionName: 'reserveFactorWad', chainId: CHAIN_ID },
      { address: p, abi: poolAbi, functionName: 'paused', chainId: CHAIN_ID },
      { address: v, abi: vaultAbi, functionName: 'totalAssets', chainId: CHAIN_ID },
      { address: v, abi: vaultAbi, functionName: 'totalSupply', chainId: CHAIN_ID },
      { address: v, abi: vaultAbi, functionName: 'sharePrice', chainId: CHAIN_ID },
      { address: v, abi: vaultAbi, functionName: 'paused', chainId: CHAIN_ID },
      { address: r, abi: riskAbi, functionName: 'protocolPaused', chainId: CHAIN_ID },
      { address: r, abi: riskAbi, functionName: 'getRisk', args: [v], chainId: CHAIN_ID },
      { address: r, abi: riskAbi, functionName: 'getRisk', args: [p], chainId: CHAIN_ID },
      { address: m, abi: rateModelAbi, functionName: 'baseRate', chainId: CHAIN_ID },
      { address: m, abi: rateModelAbi, functionName: 'optimalUtilization', chainId: CHAIN_ID },
      { address: m, abi: rateModelAbi, functionName: 'slope1', chainId: CHAIN_ID },
      { address: m, abi: rateModelAbi, functionName: 'slope2', chainId: CHAIN_ID },
    ],
    query: { enabled: ready, refetchInterval: REFRESH_MS },
  })

  const holder = account ?? zeroAddress
  const userReads = useReadContracts({
    allowFailure: false,
    contracts: [
      { address: USDC_ADDRESS, abi: erc20Abi, functionName: 'balanceOf', args: [holder], chainId: CHAIN_ID },
      { address: USDC_ADDRESS, abi: erc20Abi, functionName: 'allowance', args: [holder, v], chainId: CHAIN_ID },
      { address: USDC_ADDRESS, abi: erc20Abi, functionName: 'allowance', args: [holder, p], chainId: CHAIN_ID },
      { address: v, abi: vaultAbi, functionName: 'balanceOf', args: [holder], chainId: CHAIN_ID },
      { address: p, abi: poolAbi, functionName: 'balanceOf', args: [holder], chainId: CHAIN_ID },
    ],
    query: { enabled: ready && Boolean(account), refetchInterval: REFRESH_MS },
  })
  const shares = userReads.data?.[3]
  const vaultValue = useReadContract({
    address: v,
    abi: vaultAbi,
    functionName: 'convertToAssets',
    args: [shares ?? 0n],
    chainId: CHAIN_ID,
    query: { enabled: ready && shares !== undefined, refetchInterval: REFRESH_MS },
  })

  const d = state.data
  const u = userReads.data

  return {
    isDeployed: enabled,
    isLoading: enabled && (wiring.isLoading || (ready && state.isLoading)),
    error: (wiring.error ?? state.error ?? null),
    refetch: () => {
      void wiring.refetch()
      void state.refetch()
      void userReads.refetch()
      void vaultValue.refetch()
    },
    addresses: { factory: FACTORY_ADDRESS, vault, pool, risk, rateModel },
    pool: d && {
      supplied: d[0],
      borrowed: d[1],
      reserves: d[2],
      liquidity: d[3],
      utilization: d[4],
      borrowRate: d[5],
      supplyRate: d[6],
      reserveFactor: d[7],
      paused: d[8],
    },
    vault: d && { totalAssets: d[9], totalSupply: d[10], sharePrice: d[11], paused: d[12] },
    risk: d && { protocolPaused: d[13], vault: d[14], pool: d[15] },
    rateModel: d && { base: d[16], optimal: d[17], slope1: d[18], slope2: d[19] },
    user:
      u && vaultValue.data !== undefined
        ? {
            usdc: u[0],
            vaultAllowance: u[1],
            poolAllowance: u[2],
            vaultShares: u[3],
            vaultAssets: vaultValue.data,
            poolAssets: u[4],
          }
        : undefined,
  }
}
