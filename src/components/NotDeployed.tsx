import { EmptyState } from '@/components/ui'

export function NotDeployed() {
  return (
    <EmptyState
      title="ARCADIA contracts are not connected yet"
      body="This app reads live data from the deployed ARCADIA contracts on Arc Testnet. Once the contract addresses are configured, balances, markets and history appear here."
    />
  )
}
