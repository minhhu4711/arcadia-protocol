import { useEffect, useRef, useState } from 'react'
import { ConnectKitButton } from 'connectkit'
import { Check, ChevronDown, Copy, LogOut } from 'lucide-react'
import { toast } from 'sonner'
import { useUSDCBalance } from '@/hooks/useUSDCBalance'
import { useWallet } from '@/hooks/useWallet'
import { fmtUsdc, shortAddr } from '@/lib/format'

export function WalletButton() {
  const { address, isConnected, isConnecting, disconnect, connectorName } = useWallet()
  const { balance } = useUSDCBalance()
  const [open, setOpen] = useState(false)
  const [copied, setCopied] = useState(false)
  const ref = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (!open) return
    const onDown = (e: MouseEvent) => ref.current && !ref.current.contains(e.target as Node) && setOpen(false)
    document.addEventListener('mousedown', onDown)
    return () => document.removeEventListener('mousedown', onDown)
  }, [open])

  if (!isConnected || !address) {
    return (
      <ConnectKitButton.Custom>
        {({ show }) => (
          <button onClick={show} className="min-h-10 rounded-xl bg-brand px-4 text-sm font-semibold text-white">
            {isConnecting ? 'Connecting...' : 'Connect wallet'}
          </button>
        )}
      </ConnectKitButton.Custom>
    )
  }

  async function copy() {
    if (!address) return
    try {
      await navigator.clipboard.writeText(address)
      setCopied(true)
      setTimeout(() => setCopied(false), 1500)
    } catch {
      toast.error('Could not copy the address.')
    }
  }

  return (
    <div className="relative" ref={ref}>
      <button
        onClick={() => setOpen((o) => !o)}
        aria-expanded={open}
        className="flex min-h-10 items-center gap-2 rounded-xl border border-line bg-card px-3 text-sm font-medium"
      >
        <span className="mono">{shortAddr(address)}</span>
        <ChevronDown size={14} className="text-mute" />
      </button>
      {open && (
        <div className="absolute right-0 z-40 mt-2 w-72 rounded-2xl border border-line bg-panel p-4 shadow-xl">
          <div className="label">Connected with {connectorName ?? 'wallet'}</div>
          <div className="mono mt-1 break-all text-xs">{address}</div>
          <div className="mt-3 flex items-baseline justify-between border-t border-line pt-3 text-sm">
            <span className="text-mute">USDC balance</span>
            <span className="num font-semibold">{fmtUsdc(balance)}</span>
          </div>
          <p className="mt-1 text-[11px] text-mute">On Arc, this one USDC balance also pays network fees.</p>
          <div className="mt-3 grid grid-cols-2 gap-2">
            <button onClick={() => void copy()} className="flex min-h-10 items-center justify-center gap-2 rounded-xl border border-line text-sm hover:bg-card">
              {copied ? <Check size={14} className="text-ok" /> : <Copy size={14} />} {copied ? 'Copied' : 'Copy'}
            </button>
            <button
              onClick={() => {
                disconnect()
                setOpen(false)
              }}
              className="flex min-h-10 items-center justify-center gap-2 rounded-xl border border-line text-sm text-bad hover:bg-card"
            >
              <LogOut size={14} /> Disconnect
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
