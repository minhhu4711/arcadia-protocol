import { decodeErrorResult, type Hex } from 'viem'
import { errorsAbi } from '@/lib/abis'
import { parseOnchainError } from '@/lib/format'

/** Turns a failed simulation or call into a short message, decoding Arcadia custom errors when present. */
export function revertMessage(error: unknown): string {
  const data = (error as { data?: Hex; cause?: { data?: Hex } } | undefined)?.data ?? (error as { cause?: { data?: Hex } })?.cause?.data
  if (typeof data === 'string' && data.startsWith('0x') && data.length >= 10) {
    try {
      const decoded = decodeErrorResult({ abi: errorsAbi, data })
      return parseOnchainError({ message: decoded.errorName }) ?? 'Transaction would fail.'
    } catch {
      /* fall through to the generic parser */
    }
  }
  return parseOnchainError(error) ?? 'Simulation was rejected.'
}
