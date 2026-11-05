import { fireEvent, render, screen } from '@testing-library/react'
import { describe, expect, it, vi } from 'vitest'
import { APYDisplay } from '@/components/APYDisplay'
import { ConfirmModal } from '@/components/ConfirmModal'
import { MarketTable } from '@/components/MarketTable'
import { TransactionStatus } from '@/components/TransactionStatus'
import type { MarketRow } from '@/lib/markets'

const row = (id: string, name: string, supplied: number, paused = false): MarketRow => ({
  id,
  name,
  asset: 'USDC',
  supplyRate: 0n,
  borrowRate: undefined,
  supplied: BigInt(supplied) * 10n ** 6n,
  liquidity: BigInt(supplied) * 10n ** 6n,
  utilization: 0n,
  paused,
})

describe('APYDisplay', () => {
  it('shows a percentage when available', () => {
    render(<APYDisplay wad={45n * 10n ** 15n} />)
    expect(screen.getByText('4.50%')).toBeInTheDocument()
  })
  it('shows Unavailable instead of inventing a number', () => {
    render(<APYDisplay wad={undefined} unavailableReason="Borrowing is not live" />)
    expect(screen.getByText(/unavailable/i)).toBeInTheDocument()
  })
})

describe('MarketTable', () => {
  const rows = [row('a', 'Alpha Market', 100), row('b', 'Beta Market', 900), row('c', 'Gamma Market', 500, true)]
  const names = () => screen.getAllByRole('row').slice(1).map((r) => /(\w+) Market/.exec(r.textContent ?? '')?.[1] ? `${/(\w+) Market/.exec(r.textContent ?? '')?.[1]} Market` : undefined)

  it('sorts by total supplied, descending by default, and toggles', () => {
    render(<MarketTable rows={rows} loading={false} onSupply={vi.fn()} onWithdraw={vi.fn()} />)
    expect(names()).toEqual(['Beta Market', 'Gamma Market', 'Alpha Market'])
    fireEvent.click(screen.getByRole('button', { name: /total supplied/i }))
    expect(names()).toEqual(['Alpha Market', 'Gamma Market', 'Beta Market'])
  })
  it('filters by text and by status', () => {
    render(<MarketTable rows={rows} loading={false} onSupply={vi.fn()} onWithdraw={vi.fn()} />)
    fireEvent.change(screen.getByLabelText('Filter markets'), { target: { value: 'alpha' } })
    expect(names()).toEqual(['Alpha Market'])
    fireEvent.change(screen.getByLabelText('Filter markets'), { target: { value: '' } })
    fireEvent.change(screen.getByLabelText('Filter by status'), { target: { value: 'paused' } })
    expect(names()).toEqual(['Gamma Market'])
  })
  it('shows an empty state when nothing matches', () => {
    render(<MarketTable rows={rows} loading={false} onSupply={vi.fn()} onWithdraw={vi.fn()} />)
    fireEvent.change(screen.getByLabelText('Filter markets'), { target: { value: 'zzz' } })
    expect(screen.getByText('No markets match')).toBeInTheDocument()
  })
  it('reports borrow rates as unavailable and calls the supply handler', () => {
    const onSupply = vi.fn()
    render(<MarketTable rows={[row('a', 'Alpha Market', 1)]} loading={false} onSupply={onSupply} onWithdraw={vi.fn()} />)
    expect(screen.getByText(/unavailable/i)).toBeInTheDocument()
    fireEvent.click(screen.getByRole('button', { name: 'Supply' }))
    expect(onSupply).toHaveBeenCalledWith('a')
  })
})

describe('TransactionStatus', () => {
  it('renders nothing when idle', () => {
    const { container } = render(<TransactionStatus state={{ status: 'idle' }} />)
    expect(container).toBeEmptyDOMElement()
  })
  it('shows pending until a receipt exists, with an explorer link', () => {
    const hash = `0x${'ab'.repeat(32)}` as const
    render(<TransactionStatus state={{ status: 'confirming', step: 'Deposit', hash }} />)
    expect(screen.getByRole('status')).toHaveTextContent(/pending/i)
    expect(screen.getByRole('link')).toHaveAttribute('href', expect.stringContaining(hash))
  })
  it('shows success only for the success state, and errors with an alert', () => {
    const { rerender } = render(<TransactionStatus state={{ status: 'success' }} />)
    expect(screen.getByRole('status')).toHaveTextContent(/confirmed onchain/i)
    rerender(<TransactionStatus state={{ status: 'error', error: 'The transaction reverted onchain.' }} />)
    expect(screen.getByRole('alert')).toHaveTextContent(/reverted/i)
  })
})

describe('ConfirmModal', () => {
  it('confirms, cancels and closes on Escape', () => {
    const onConfirm = vi.fn()
    const onCancel = vi.fn()
    render(<ConfirmModal open title="Pause" confirmLabel="Pause now" onConfirm={onConfirm} onCancel={onCancel}>body</ConfirmModal>)
    fireEvent.click(screen.getByRole('button', { name: 'Pause now' }))
    expect(onConfirm).toHaveBeenCalledOnce()
    fireEvent.keyDown(window, { key: 'Escape' })
    expect(onCancel).toHaveBeenCalledOnce()
  })
  it('renders nothing when closed', () => {
    render(<ConfirmModal open={false} title="x" confirmLabel="y" onConfirm={vi.fn()} onCancel={vi.fn()}>z</ConfirmModal>)
    expect(screen.queryByRole('dialog')).toBeNull()
  })
})
