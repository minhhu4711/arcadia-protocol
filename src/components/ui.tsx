import type { ReactNode } from 'react'
import { AlertTriangle, Info, Inbox } from 'lucide-react'
import { clsx } from 'clsx'

export function Card({ children, className }: { children: ReactNode; className?: string }) {
  return <section className={clsx('rounded-2xl border border-line bg-card p-5', className)}>{children}</section>
}

export function Skeleton({ className }: { className?: string }) {
  return <div className={clsx('skeleton', className)} aria-hidden="true" />
}

export function InfoTip({ text }: { text: string }) {
  return (
    <span className="group relative inline-flex align-middle">
      <Info size={13} className="cursor-help text-mute" aria-label={text} />
      <span
        role="tooltip"
        className="pointer-events-none absolute bottom-full left-1/2 z-20 mb-2 hidden w-56 -translate-x-1/2 rounded-lg border border-line bg-panel px-3 py-2 text-xs normal-case leading-relaxed tracking-normal text-ink shadow-lg group-hover:block"
      >
        {text}
      </span>
    </span>
  )
}

export function StatCard({
  label,
  value,
  sub,
  tip,
  loading,
  accent,
}: {
  label: string
  value: ReactNode
  sub?: ReactNode
  tip?: string
  loading?: boolean
  accent?: 'brand' | 'aqua'
}) {
  return (
    <Card className="flex flex-col gap-2">
      <div className="label flex items-center gap-1.5">
        {label}
        {tip && <InfoTip text={tip} />}
      </div>
      {loading ? (
        <Skeleton className="h-8 w-32" />
      ) : (
        <div
          className={clsx(
            'display num text-2xl font-semibold md:text-3xl',
            accent === 'brand' && 'text-brand',
            accent === 'aqua' && 'text-aqua',
          )}
        >
          {value}
        </div>
      )}
      {sub && <div className="text-xs text-mute">{sub}</div>}
    </Card>
  )
}

export function Badge({ tone, children }: { tone: 'ok' | 'warn' | 'bad' | 'mute' | 'brand'; children: ReactNode }) {
  const tones = {
    ok: 'bg-ok/10 text-ok border-ok/30',
    warn: 'bg-warn/10 text-warn border-warn/30',
    bad: 'bg-bad/10 text-bad border-bad/30',
    mute: 'bg-line/40 text-mute border-line',
    brand: 'bg-brand/10 text-brand border-brand/30',
  }
  return (
    <span className={clsx('inline-flex items-center rounded-full border px-2.5 py-0.5 text-xs font-medium', tones[tone])}>
      {children}
    </span>
  )
}

export function EmptyState({ title, body, action }: { title: string; body: string; action?: ReactNode }) {
  return (
    <div className="flex flex-col items-center gap-3 rounded-2xl border border-dashed border-line px-6 py-12 text-center">
      <Inbox size={28} className="text-mute" />
      <div className="display text-lg font-semibold">{title}</div>
      <p className="max-w-sm text-pretty text-sm text-mute">{body}</p>
      {action}
    </div>
  )
}

export function ErrorState({ message, onRetry }: { message: string; onRetry?: () => void }) {
  return (
    <div className="flex items-start gap-3 rounded-2xl border border-bad/40 bg-bad/5 p-4 text-sm">
      <AlertTriangle size={18} className="mt-0.5 shrink-0 text-bad" />
      <div className="flex-1">
        <div className="font-medium text-bad">Could not load onchain data</div>
        <div className="text-mute">{message}</div>
      </div>
      {onRetry && (
        <button onClick={onRetry} className="rounded-lg border border-line px-3 py-1.5 text-xs hover:bg-panel">
          Retry
        </button>
      )}
    </div>
  )
}

export function PageHeader({ title, subtitle, right }: { title: string; subtitle: string; right?: ReactNode }) {
  return (
    <div className="mb-6 flex flex-wrap items-end justify-between gap-3">
      <div>
        <h1 className="display text-balance text-2xl font-semibold md:text-3xl">{title}</h1>
        <p className="mt-1 max-w-xl text-pretty text-sm text-mute">{subtitle}</p>
      </div>
      {right}
    </div>
  )
}

export function Row({ label, value, tip }: { label: string; value: ReactNode; tip?: string }) {
  return (
    <div className="flex items-center justify-between gap-4 py-2 text-sm">
      <span className="flex items-center gap-1.5 text-mute">
        {label}
        {tip && <InfoTip text={tip} />}
      </span>
      <span className="num text-right font-medium">{value}</span>
    </div>
  )
}
