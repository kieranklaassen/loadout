import { act, fireEvent, render, screen } from '@testing-library/react'
import type { ReactNode } from 'react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import ConnectAgentCard, { AGENT_PROMPT } from './connect_agent_card'

vi.mock('@inertiajs/react', () => ({
  Link: ({ href, children, ...rest }: { href: string; children: ReactNode }) => (
    <a href={href} {...rest}>
      {children}
    </a>
  ),
}))

describe('ConnectAgentCard', () => {
  const writeText = vi.fn().mockResolvedValue(undefined)

  beforeEach(() => {
    vi.useFakeTimers()
    Object.defineProperty(navigator, 'clipboard', { value: { writeText }, configurable: true })
  })

  afterEach(() => {
    vi.useRealTimers()
    writeText.mockClear()
  })

  it('links to the Agents page with a real link and names the supported clients', () => {
    render(<ConnectAgentCard />)

    expect(screen.getByRole('heading', { level: 3, name: 'Connect your agent' })).toBeInTheDocument()
    expect(screen.getByRole('link', { name: /set up an agent/i })).toHaveAttribute('href', '/agents')
    expect(screen.getByText(/Claude, Claude Code, Cursor or Codex/)).toBeInTheDocument()
    expect(screen.getByText(/until you confirm it/i)).toBeInTheDocument()
  })

  it('copies the suggested prompt from a button and says so', async () => {
    render(<ConnectAgentCard />)

    await act(async () => {
      fireEvent.click(screen.getByRole('button', { name: new RegExp(AGENT_PROMPT.slice(0, 20)) }))
    })

    expect(writeText).toHaveBeenCalledWith(AGENT_PROMPT)
    expect(screen.getByRole('button', { name: /copied/i })).toBeInTheDocument()

    act(() => {
      vi.advanceTimersByTime(1900)
    })
    expect(screen.getByRole('button', { name: /tap to copy/i })).toBeInTheDocument()
  })

  it('leaves out the prompt button when compact', () => {
    render(<ConnectAgentCard compact />)

    expect(screen.queryByRole('button')).not.toBeInTheDocument()
    expect(screen.getByRole('link', { name: /set up an agent/i })).toBeInTheDocument()
  })

  it('takes the page colours and sharp corners from the design tokens', () => {
    const { container } = render(<ConnectAgentCard className="mt-8" />)

    const card = container.firstElementChild as HTMLElement
    expect(card).toHaveClass('panel', 'mt-8')
    expect(screen.getByRole('link', { name: /set up an agent/i })).toHaveClass('rounded-sharp')
  })
})
