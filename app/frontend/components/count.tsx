import type { Count as CountValue } from '../types'

/** "5 of 6 use it": the one way every surface writes N of M. */
export default function Count({ count, label, className = '' }: { count: CountValue; label?: string; className?: string }) {
  return <span className={`tabular-nums ${className}`}>{`${count.n} of ${count.of}${label ? ` ${label}` : ''}`}</span>
}
