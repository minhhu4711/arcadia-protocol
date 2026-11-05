import { NavLink } from 'react-router-dom'
import { BarChart3, Clock, Landmark, LayoutDashboard, Shield, Vault, Wallet } from 'lucide-react'
import { clsx } from 'clsx'

export const NAV = [
  { to: '/', label: 'Overview', icon: LayoutDashboard },
  { to: '/vault', label: 'Vault', icon: Vault },
  { to: '/markets', label: 'Markets', icon: Landmark },
  { to: '/portfolio', label: 'Portfolio', icon: Wallet },
  { to: '/history', label: 'History', icon: Clock },
  { to: '/analytics', label: 'Analytics', icon: BarChart3 },
  { to: '/admin', label: 'Admin', icon: Shield },
]

export function Logo() {
  return (
    <div className="flex items-center gap-2.5">
      <svg width="28" height="28" viewBox="0 0 32 32" fill="none" aria-hidden="true">
        <rect width="32" height="32" rx="9" fill="#3185FF" />
        <path d="M16 6 8 26h4l1.6-4.4h4.8L20 26h4L16 6Zm0 8.2 1.6 4.6h-3.2L16 14.2Z" fill="#fff" />
      </svg>
      <div>
        <div className="display text-lg font-semibold leading-none">ARCADIA</div>
        <div className="mt-1 text-[10px] uppercase tracking-[0.12em] text-mute">Arc Testnet</div>
      </div>
    </div>
  )
}

export function Sidebar() {
  return (
    <aside className="fixed inset-y-0 left-0 hidden w-60 flex-col border-r border-line bg-panel px-4 py-6 lg:flex">
      <Logo />
      <nav className="mt-8 flex flex-1 flex-col gap-1" aria-label="Primary">
        {NAV.map(({ to, label, icon: Icon }) => (
          <NavLink
            key={to}
            to={to}
            end={to === '/'}
            className={({ isActive }) =>
              clsx('flex min-h-11 items-center gap-3 rounded-xl px-3 text-sm font-medium transition-colors', isActive ? 'bg-brand/15 text-brand' : 'text-mute hover:bg-card hover:text-ink')
            }
          >
            <Icon size={18} />
            {label}
          </NavLink>
        ))}
      </nav>
      <p className="text-pretty text-[11px] leading-relaxed text-mute">Testnet software. Contracts are not audited by a third party. Do not use real funds.</p>
    </aside>
  )
}

export function MobileNav() {
  return (
    <nav className="flex gap-1 overflow-x-auto border-b border-line px-3 py-2 lg:hidden" aria-label="Primary mobile">
      {NAV.map(({ to, label, icon: Icon }) => (
        <NavLink
          key={to}
          to={to}
          end={to === '/'}
          className={({ isActive }) => clsx('flex min-h-11 shrink-0 items-center gap-2 rounded-xl px-3 text-sm font-medium', isActive ? 'bg-brand/15 text-brand' : 'text-mute')}
        >
          <Icon size={16} />
          {label}
        </NavLink>
      ))}
    </nav>
  )
}
