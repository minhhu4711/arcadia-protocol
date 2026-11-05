import { Skeleton } from '@/components/ui'

/** Block of skeleton rows for tables and lists while data loads. */
export function LoadingSkeleton({ rows = 3, className = 'h-12' }: { rows?: number; className?: string }) {
  return (
    <div className="space-y-2" aria-busy="true" aria-label="Loading">
      {Array.from({ length: rows }, (_, i) => <Skeleton key={i} className={`${className} w-full`} />)}
    </div>
  )
}
