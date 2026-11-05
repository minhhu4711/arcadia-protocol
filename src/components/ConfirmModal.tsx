import { useEffect, type ReactNode } from 'react'

export function ConfirmModal({
  open,
  title,
  children,
  confirmLabel,
  tone = 'brand',
  onConfirm,
  onCancel,
}: {
  open: boolean
  title: string
  children: ReactNode
  confirmLabel: string
  tone?: 'brand' | 'danger'
  onConfirm: () => void
  onCancel: () => void
}) {
  useEffect(() => {
    if (!open) return
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onCancel()
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [open, onCancel])

  if (!open) return null
  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/60 p-4 sm:items-center" role="dialog" aria-modal="true" aria-label={title}>
      <div className="w-full max-w-md rounded-2xl border border-line bg-card p-6 shadow-2xl">
        <h2 className="display text-xl font-semibold">{title}</h2>
        <div className="mt-3 space-y-2 text-sm text-mute">{children}</div>
        <div className="mt-6 flex gap-3">
          <button onClick={onCancel} className="min-h-11 flex-1 rounded-xl border border-line text-sm font-medium hover:bg-panel">
            Cancel
          </button>
          <button
            onClick={onConfirm}
            className={`min-h-11 flex-1 rounded-xl text-sm font-semibold text-white ${tone === 'danger' ? 'bg-bad' : 'bg-brand'}`}
          >
            {confirmLabel}
          </button>
        </div>
      </div>
    </div>
  )
}
