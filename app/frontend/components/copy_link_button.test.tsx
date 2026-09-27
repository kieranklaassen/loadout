import { act, fireEvent, render, screen } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { CopyLinkButton } from './copy_link_button'

describe('CopyLinkButton', () => {
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
    render(<CopyLinkButton url="https://loadout.every.to/ana" />)

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
})
