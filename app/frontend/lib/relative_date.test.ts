import { describe, expect, it } from 'vitest'
import { relativeDate, shortDate, staleness } from './relative_date'

describe('relativeDate', () => {
  const now = new Date('2026-09-26T12:00:00Z')
  const ago = (ms: number) => new Date(now.getTime() - ms).toISOString()

  it('reads naturally across ranges', () => {
    expect(relativeDate(ago(10_000), now)).toBe('just now')
    expect(relativeDate(ago(5 * 60_000), now)).toBe('5 min ago')
    expect(relativeDate(ago(3_600_000), now)).toBe('1 hour ago')
    expect(relativeDate(ago(5 * 3_600_000), now)).toBe('5 hours ago')
    expect(relativeDate(ago(30 * 3_600_000), now)).toBe('yesterday')
    expect(relativeDate(ago(4 * 86_400_000), now)).toBe('4 days ago')
    expect(relativeDate('2026-09-01T12:00:00Z', now)).toBe('Sep 1')
    expect(relativeDate('2025-03-14T12:00:00Z', now)).toBe('Mar 14, 2025')
  })
})

describe('shortDate', () => {
  const now = new Date('2026-09-26T12:00:00Z')

  it('writes month and day, adding the year only for another year', () => {
    expect(shortDate('2026-09-19T18:00:00Z', now)).toBe('Sep 19')
    expect(shortDate('2025-03-14T12:00:00Z', now)).toBe('Mar 14, 2025')
  })

  it('reads a date-only string and a late-evening time as their UTC day, whatever the browser zone', () => {
    expect(shortDate('2026-09-22', now)).toBe('Sep 22')
    expect(shortDate('2026-09-22T23:30:00Z', now)).toBe('Sep 22')
  })
})

describe('staleness', () => {
  const now = new Date('2026-09-26T12:00:00Z')
  const daysAgo = (days: number) => new Date(now.getTime() - days * 86_400_000).toISOString()

  it('counts weeks from six, up to eight', () => {
    expect(staleness(daysAgo(42), now)).toBe('Not updated in 6 weeks')
    expect(staleness(daysAgo(49), now)).toBe('Not updated in 7 weeks')
    expect(staleness(daysAgo(62), now)).toBe('Not updated in 8 weeks')
  })

  it('counts months after eight weeks', () => {
    expect(staleness(daysAgo(63), now)).toBe('Not updated in 2 months')
    expect(staleness(daysAgo(95), now)).toBe('Not updated in 3 months')
    expect(staleness(daysAgo(400), now)).toBe('Not updated in 13 months')
  })

  it('counts UTC calendar days, so the time of day does not move the week', () => {
    const late = new Date('2026-09-26T00:30:00Z')
    expect(staleness('2026-08-15T23:59:00Z', late)).toBe('Not updated in 6 weeks')
  })
})
