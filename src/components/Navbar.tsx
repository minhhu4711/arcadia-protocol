import { Logo } from '@/components/Sidebar'
import { NetworkIndicator } from '@/components/NetworkIndicator'
import { WalletButton } from '@/components/WalletButton'

export function Navbar() {
  return (
    <header className="sticky top-0 z-30 flex items-center justify-between gap-3 border-b border-line bg-base/90 px-4 py-3 backdrop-blur md:px-8">
      <div className="lg:hidden">
        <Logo />
      </div>
      <div className="hidden text-sm text-mute lg:block">Where Capital Finds Its Flow.</div>
      <div className="flex items-center gap-2">
        <NetworkIndicator />
        <WalletButton />
      </div>
    </header>
  )
}
