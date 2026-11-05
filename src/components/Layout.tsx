import { Outlet } from 'react-router-dom'
import { Navbar } from '@/components/Navbar'
import { MobileNav, Sidebar } from '@/components/Sidebar'

export function Layout() {
  return (
    <div className="min-h-dvh bg-base">
      <Sidebar />
      <div className="lg:pl-60">
        <Navbar />
        <MobileNav />
        <main className="mx-auto max-w-6xl px-4 py-6 pb-24 md:px-8 md:py-8">
          <Outlet />
        </main>
      </div>
    </div>
  )
}
