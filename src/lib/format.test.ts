import { describe, expect, it } from 'vitest'
import { fmtPctWad, fmtUsdCompact, fmtUsdc, parseOnchainError, shortAddr } from '@/lib/format'

describe('fmtUsdc', () => {
  it('formats base units without floating point error', () => {
    expect(fmtUsdc(1_234_567_890n)).toBe('1,234.56')
    expect(fmtUsdc(1n, 6)).toBe('0.000001')
    expect(fmtUsdc(0n)).toBe('0.00')
  })
  it('shows a placeholder when the value is unavailable', () => {
    expect(fmtUsdc(undefined)).toBe('--')
  })
  it('handles very large amounts exactly', () => {
    expect(fmtUsdc(123_456_789_012_345_678n, 0)).toBe('123,456,789,012')
  })
})

describe('fmtUsdCompact', () => {
  it('compacts thousands and millions', () => {
    expect(fmtUsdCompact(12_500n * 10n ** 6n)).toBe('$12.5K')
    expect(fmtUsdCompact(3_400_000n * 10n ** 6n)).toBe('$3.4M')
    expect(fmtUsdCompact(undefined)).toBe('--')
  })
})

describe('fmtPctWad', () => {
  it('converts a WAD fraction to a percent', () => {
    expect(fmtPctWad(10n ** 18n)).toBe('100.00%')
    expect(fmtPctWad(45n * 10n ** 15n)).toBe('4.50%')
    expect(fmtPctWad(0n)).toBe('0.00%')
    expect(fmtPctWad(undefined)).toBe('--')
  })
})

describe('shortAddr', () => {
  it('shortens an address', () => {
    expect(shortAddr('0x77B6F96FA7a5544c3Ecd2fAF8D870FD340b32182')).toBe('0x77B6...2182')
    expect(shortAddr(undefined)).toBe('--')
  })
})

describe('parseOnchainError', () => {
  it('treats a rejected signature as a silent cancel', () => {
    expect(parseOnchainError({ code: 4001, message: 'x' })).toBeNull()
    expect(parseOnchainError({ message: 'User rejected the request.' })).toBeNull()
  })
  it('maps protocol reverts to readable messages', () => {
    expect(parseOnchainError({ message: 'DepositCapExceeded' })).toMatch(/cap/i)
    expect(parseOnchainError({ message: 'WithdrawalsPaused' })).toMatch(/paused/i)
    expect(parseOnchainError({ message: 'InsufficientLiquidity' })).toMatch(/liquidity/i)
  })
  it('maps balance, gas and RPC failures', () => {
    expect(parseOnchainError({ message: 'insufficient funds for gas * price + value' })).toMatch(/network fee/i)
    expect(parseOnchainError({ message: 'exceeds balance' })).toMatch(/insufficient/i)
    expect(parseOnchainError({ message: 'HTTP request failed' })).toMatch(/network/i)
  })
  it('falls back to a generic message', () => {
    expect(parseOnchainError({ message: 'boom' })).toMatch(/something went wrong/i)
  })
})

describe('parseOnchainError wallet authorization', () => {
  it('explains an unauthorized wallet account', () => {
    expect(parseOnchainError({ code: 4100, message: 'x' })).toMatch(/not authorized/i)
    expect(parseOnchainError({ message: 'The requested method and/or account has not been authorized by the user.' })).toMatch(/reconnect/i)
  })
})
