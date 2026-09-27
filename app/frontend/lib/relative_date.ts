const MINUTE = 60_000
const HOUR = 60 * MINUTE
const DAY = 24 * HOUR

/** "just now", "5 min ago", "yesterday", "4 days ago", "Sep 12", "Sep 12, 2025". */
export function relativeDate(iso: string, now: Date = new Date()): string {
  const date = new Date(iso)
  const elapsed = now.getTime() - date.getTime()

  if (elapsed < MINUTE) return 'just now'
  if (elapsed < HOUR) return `${Math.floor(elapsed / MINUTE)} min ago`
  if (elapsed < DAY) {
    const hours = Math.floor(elapsed / HOUR)
    return `${hours} ${hours === 1 ? 'hour' : 'hours'} ago`
  }

  const days = Math.floor(elapsed / DAY)
  if (days === 1) return 'yesterday'
  if (days < 7) return `${days} days ago`

  const sameYear = date.getFullYear() === now.getFullYear()
  return date.toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    ...(sameYear ? {} : { year: 'numeric' }),
  })
}

export function fullDate(iso: string): string {
  return new Date(iso).toLocaleDateString('en-US', { dateStyle: 'long' })
}

/** "Sep 19", or "Sep 19, 2025" in another year. Reads the UTC day, so a date-only "2026-09-22" is Sep 22 in every zone. */
export function shortDate(iso: string, now: Date = new Date()): string {
  const date = new Date(iso)
  const sameYear = date.getUTCFullYear() === now.getUTCFullYear()
  return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', ...(sameYear ? {} : { year: 'numeric' }), timeZone: 'UTC' })
}

const utcDay = (date: Date) => Math.floor(date.getTime() / DAY)

/** "Not updated in 6 weeks" in weeks up to 8, then "Not updated in 3 months"; counts UTC calendar days like the server's stale flag. */
export function staleness(iso: string, now: Date = new Date()): string {
  const days = utcDay(now) - utcDay(new Date(iso))
  const weeks = Math.floor(days / 7)
  return weeks <= 8 ? `Not updated in ${weeks} weeks` : `Not updated in ${Math.floor(days / 30)} months`
}
