import { formatUnitsFixed } from '@/onchain-money'
import { USDC_DECIMALS } from '@/onchain-facts'

const WAD = 10n ** 18n

function group(intPart: string): string {
  return intPart.replace(/\B(?=(\d{3})+(?!\d))/g, ',')
}

/** USDC base units (6 decimals) to "1,234.56". Bigint math only. */
export function fmtUsdc(raw: bigint | undefined, digits = 2): string {
  if (raw === undefined) return '--'
  const negative = raw < 0n
  const fixed = formatUnitsFixed(negative ? -raw : raw, USDC_DECIMALS, digits)
  const [i, f] = fixed.split('.')
  return `${negative ? '-' : ''}${group(i)}${f ? `.${f}` : ''}`
}

/** Compact currency for large headline numbers: $1.2M, $34.5K. */
export function fmtUsdCompact(raw: bigint | undefined): string {
  if (raw === undefined) return '--'
  const whole = raw / 10n ** BigInt(USDC_DECIMALS)
  if (whole >= 1_000_000_000n) return `$${Number(whole / 10_000_000n) / 100}B`
  if (whole >= 1_000_000n) return `$${Number(whole / 10_000n) / 100}M`
  if (whole >= 10_000n) return `$${Number(whole / 10n) / 100}K`
  return `$${fmtUsdc(raw)}`
}

/** WAD fraction (1e18 = 100%) to a percent string with two decimals. */
export function fmtPctWad(wad: bigint | undefined): string {
  if (wad === undefined) return '--'
  const hundredths = wad / (WAD / 10_000n)
  return `${(Number(hundredths) / 100).toFixed(2)}%`
}

export function shortAddr(addr: string | undefined): string {
  return addr ? `${addr.slice(0, 6)}...${addr.slice(-4)}` : '--'
}

export function timeAgo(tsSeconds: number): string {
  const diff = Math.max(0, Math.floor(Date.now() / 1000) - tsSeconds)
  if (diff < 60) return `${diff}s ago`
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`
  return `${Math.floor(diff / 86400)}d ago`
}

export function parseOnchainError(error: unknown): string | null {
  const e = error as { code?: number; shortMessage?: string; message?: string } | undefined
  const message = (e?.shortMessage ?? e?.message ?? '').toLowerCase()
  if (e?.code === 4001 || message.includes('user rejected') || message.includes('user denied')) return null
  if (message.includes('not been authorized') || e?.code === 4100) return 'Your wallet has not authorized this app for the account. Approve the connection request in your wallet, or disconnect and reconnect, then try again.'
  if (message.includes('depositcapexceeded')) return 'The deposit cap would be exceeded.'
  if (message.includes('belowmindeposit')) return 'Amount is below the minimum deposit.'
  if (message.includes('abovemaxdepositpertx')) return 'Amount is above the per-transaction deposit limit.'
  if (message.includes('abovemaxwithdrawpertx')) return 'Amount is above the per-transaction withdrawal limit.'
  if (message.includes('withdrawalspaused')) return 'Withdrawals are currently paused by risk controls.'
  if (message.includes('protocolpaused')) return 'The protocol is paused.'
  if (message.includes('insufficientliquidity')) return 'Not enough available liquidity for this amount.'
  if (message.includes('accesscontrol') || message.includes('unauthorized')) return 'Your wallet does not hold the required role.'
  if (message.includes('enforcedpause')) return 'This contract is paused.'
  if (message.includes('insufficient funds for gas') || message.includes('gas required exceeds')) return 'Not enough USDC to pay the network fee.'
  if (message.includes('insufficient funds') || message.includes('exceeds balance')) return 'Insufficient balance for this transaction.'
  if (message.includes('http request failed') || message.includes('fetch failed') || message.includes('timeout') || message.includes('network')) return 'Network issue. Check your connection and retry.'
  if (message.includes('reverted')) return 'The transaction reverted onchain.'
  const detail = (e?.shortMessage ?? e?.message ?? '').split('\n')[0].trim().slice(0, 140)
  return detail ? `Something went wrong: ${detail}` : 'Something went wrong. Please try again.'
}
