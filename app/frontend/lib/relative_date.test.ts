import { describe, expect, it } from 'vitest'
import { relativeDate } from './relative_date'

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
