import { isAddress, type Address } from 'viem'
import { arcTestnet } from 'viem/chains'
import { getUsdc, requireChain } from '@/onchain-facts'

export const CHAIN_ID = arcTestnet.id
export const CHAIN = requireChain(CHAIN_ID)

const usdcFact = getUsdc(CHAIN_ID)
if (!usdcFact) throw new Error('USDC is not registered for Arc Testnet')
export const USDC_ADDRESS: Address = usdcFact.address as Address

function envAddress(value: string | undefined): Address | undefined {
  return value && isAddress(value) ? value : undefined
}

/** Addresses of the deployed Arcadia contracts. Set in .env (VITE_ prefix, public values only). */
export const FACTORY_ADDRESS = envAddress(import.meta.env.VITE_ARCADIA_FACTORY)
export const VAULT_ADDRESS = envAddress(import.meta.env.VITE_ARCADIA_VAULT)

const block = Number(import.meta.env.VITE_ARCADIA_DEPLOY_BLOCK ?? '')
/** First block that can contain Arcadia events. Undefined when not configured. */
export const DEPLOY_BLOCK: bigint | undefined = Number.isFinite(block) && block > 0 ? BigInt(block) : undefined

export const isDeployed = Boolean(FACTORY_ADDRESS && VAULT_ADDRESS)
