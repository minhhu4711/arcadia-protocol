import { encodeFunctionData, erc20Abi, type Address, type Hex } from 'viem'
import { poolAbi, vaultAbi } from '@/lib/abis'
import { USDC_ADDRESS } from '@/lib/deployments'

export type MarketKind = 'vault' | 'pool'
export type MoneyMode = 'deposit' | 'withdraw'

export interface Call {
  label: string
  to: Address
  data: Hex
}

export function approveCall(spender: Address, amount: bigint): Call {
  return {
    label: 'Approve USDC',
    to: USDC_ADDRESS,
    data: encodeFunctionData({ abi: erc20Abi, functionName: 'approve', args: [spender, amount] }),
  }
}

export interface MoneyCallInput {
  kind: MarketKind
  mode: MoneyMode
  target: Address
  account: Address
  amount: bigint
  /** True when the amount equals the full position: use the exact-exit function. */
  isMax: boolean
  /** The account's vault share balance, needed for a full vault exit. */
  vaultShares: bigint
}

/** The single state-changing call for a deposit, supply or withdrawal. */
export function moneyCall(input: MoneyCallInput): Call {
  const { kind, mode, target, account, amount, isMax, vaultShares } = input
  if (kind === 'vault') {
    if (mode === 'deposit') {
      return { label: 'Deposit', to: target, data: encodeFunctionData({ abi: vaultAbi, functionName: 'deposit', args: [amount, account] }) }
    }
    return isMax
      ? { label: 'Withdraw', to: target, data: encodeFunctionData({ abi: vaultAbi, functionName: 'redeem', args: [vaultShares, account, account] }) }
      : { label: 'Withdraw', to: target, data: encodeFunctionData({ abi: vaultAbi, functionName: 'withdraw', args: [amount, account, account] }) }
  }
  if (mode === 'deposit') {
    return { label: 'Supply', to: target, data: encodeFunctionData({ abi: poolAbi, functionName: 'supply', args: [amount] }) }
  }
  return isMax
    ? { label: 'Withdraw', to: target, data: encodeFunctionData({ abi: poolAbi, functionName: 'withdrawAll' }) }
    : { label: 'Withdraw', to: target, data: encodeFunctionData({ abi: poolAbi, functionName: 'withdraw', args: [amount] }) }
}

/** Ordered calls for an action: an exact-amount approval first when the allowance is short. */
export function buildCalls(input: MoneyCallInput, allowance: bigint): Call[] {
  const calls: Call[] = []
  if (input.mode === 'deposit' && allowance < input.amount) calls.push(approveCall(input.target, input.amount))
  calls.push(moneyCall(input))
  return calls
}
