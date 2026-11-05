import { BrowserRouter, Route, Routes } from 'react-router-dom'
import { Layout } from '@/components/Layout'
import Overview from '@/pages/Overview'
import VaultPage from '@/pages/VaultPage'
import Markets from '@/pages/Markets'
import Portfolio from '@/pages/Portfolio'
import History from '@/pages/History'
import Analytics from '@/pages/Analytics'
import Admin from '@/pages/Admin'

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route element={<Layout />}>
          <Route index element={<Overview />} />
          <Route path="vault" element={<VaultPage />} />
          <Route path="markets" element={<Markets />} />
          <Route path="portfolio" element={<Portfolio />} />
          <Route path="history" element={<History />} />
          <Route path="analytics" element={<Analytics />} />
          <Route path="admin" element={<Admin />} />
          <Route path="*" element={<Overview />} />
        </Route>
      </Routes>
    </BrowserRouter>
  )
}
