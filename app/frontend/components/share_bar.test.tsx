import { act, fireEvent, render, screen } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import ShareBar, { xIntentUrl } from './share_bar'

describe('ShareBar', () => {
  const writeText = vi.fn().mockResolvedValue(undefined)

  beforeEach(() => {
    vi.useFakeTimers()
    Object.defineProperty(navigator, 'clipboard', { value: { writeText }, configurable: true })
  })

  afterEach(() => {
    vi.useRealTimers()
    writeText.mockClear()
  })

  it('copies the link and shows a copied state that resets', async () => {
    render(<ShareBar url="https://loadout.every.to/ana" text="Ana's AI loadout" />)

    await act(async () => {
      fireEvent.click(screen.getByRole('button', { name: /copy link/i }))
    })

    expect(writeText).toHaveBeenCalledWith('https://loadout.every.to/ana')
    expect(screen.getByRole('button', { name: /link copied/i })).toBeInTheDocument()
    expect(screen.getByRole('status')).toHaveTextContent(/copied/i)

    act(() => {
      vi.advanceTimersByTime(2100)
    })
    expect(screen.getByRole('button', { name: /copy link/i })).toBeInTheDocument()
  })

  it('links to an X intent with the text and url', () => {
    render(<ShareBar url="https://loadout.every.to/ana" text="Ana's AI loadout" />)

    const link = screen.getByRole('link', { name: /share on x/i })
    const href = new URL(link.getAttribute('href') ?? '')
    expect(href.origin + href.pathname).toBe('https://x.com/intent/post')
    expect(href.searchParams.get('url')).toBe('https://loadout.every.to/ana')
    expect(href.searchParams.get('text')).toBe("Ana's AI loadout")
    expect(link).toHaveAttribute('target', '_blank')
    expect(link).toHaveAttribute('rel', expect.stringContaining('noopener'))
  })

  it('encodes the intent url', () => {
    expect(xIntentUrl('https://x.test/a b', 'a&b')).toBe('https://x.com/intent/post?text=a%26b&url=https%3A%2F%2Fx.test%2Fa+b')
  })
})
