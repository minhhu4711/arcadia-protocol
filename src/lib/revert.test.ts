import { encodeErrorResult } from 'viem'
import { describe, expect, it } from 'vitest'
import { errorsAbi } from '@/lib/abis'
import { revertMessage } from '@/lib/revert'

describe('revertMessage', () => {
  it('decodes Arcadia custom errors from revert data', () => {
    const data = encodeErrorResult({ abi: errorsAbi, errorName: 'DepositCapExceeded' })
    expect(revertMessage({ data })).toMatch(/cap/i)
    const paused = encodeErrorResult({ abi: errorsAbi, errorName: 'ProtocolPaused' })
    expect(revertMessage({ cause: { data: paused } })).toMatch(/paused/i)
  })
  it('falls back to the generic parser for unknown data', () => {
    expect(revertMessage({ message: 'exceeds balance' })).toMatch(/insufficient/i)
  })
})
