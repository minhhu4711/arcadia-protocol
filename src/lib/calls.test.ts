import { decodeFunctionData, erc20Abi, getAddress, type Address } from 'viem'
import { describe, expect, it } from 'vitest'
import { poolAbi, vaultAbi } from '@/lib/abis'
import { buildCalls, type MoneyCallInput } from '@/lib/calls'

const target = '0x08f3be286da8ba4d4638fa5472279f884b67584b' as Address
const account = '0x77B6F96FA7a5544c3Ecd2fAF8D870FD340b32182' as Address
const base: MoneyCallInput = { kind: 'vault', mode: 'deposit', target, account, amount: 5_000_000n, isMax: false, vaultShares: 7n }

describe('buildCalls', () => {
  it('prepends an exact-amount approval when the allowance is short', () => {
    const calls = buildCalls(base, 1n)
    expect(calls.map((c) => c.label)).toEqual(['Approve USDC', 'Deposit'])
    const approve = decodeFunctionData({ abi: erc20Abi, data: calls[0].data })
    expect(approve.functionName).toBe('approve')
    expect(approve.args).toEqual([getAddress(target), 5_000_000n])
  })
  it('skips the approval when the allowance already covers the amount', () => {
    expect(buildCalls(base, 5_000_000n).map((c) => c.label)).toEqual(['Deposit'])
  })
  it('deposits for the connected account', () => {
    const [call] = buildCalls(base, 10n ** 12n)
    const decoded = decodeFunctionData({ abi: vaultAbi, data: call.data })
    expect(decoded.functionName).toBe('deposit')
    expect(decoded.args).toEqual([5_000_000n, getAddress(account)])
  })
  it('uses redeem for a full vault exit and withdraw otherwise', () => {
    const full = buildCalls({ ...base, mode: 'withdraw', isMax: true }, 0n)
    expect(full).toHaveLength(1)
    expect(decodeFunctionData({ abi: vaultAbi, data: full[0].data }).functionName).toBe('redeem')
    const partial = buildCalls({ ...base, mode: 'withdraw' }, 0n)
    expect(decodeFunctionData({ abi: vaultAbi, data: partial[0].data }).functionName).toBe('withdraw')
  })
  it('supplies to and withdraws from the lending market', () => {
    const supply = buildCalls({ ...base, kind: 'pool' }, 10n ** 12n)
    expect(decodeFunctionData({ abi: poolAbi, data: supply[0].data }).functionName).toBe('supply')
    const all = buildCalls({ ...base, kind: 'pool', mode: 'withdraw', isMax: true }, 0n)
    expect(decodeFunctionData({ abi: poolAbi, data: all[0].data }).functionName).toBe('withdrawAll')
  })
})
