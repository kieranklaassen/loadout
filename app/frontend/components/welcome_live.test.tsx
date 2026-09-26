import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import type { ReactNode } from 'react'
import { describe, expect, it, vi } from 'vitest'
import WelcomeLive from './welcome_live'

vi.mock('@inertiajs/react', () => ({
  Link: ({ href, children, className }: { href: string; children: ReactNode; className?: string }) => (
    <a href={href} className={className}>
      {children}
    </a>
  ),
}))

describe('WelcomeLive', () => {
  it('celebrates, copies the link, and shares a public profile on X', async () => {
    const writeText = vi.fn().mockResolvedValue(undefined)
    Object.defineProperty(navigator, 'clipboard', { value: { writeText }, configurable: true })

    render(<WelcomeLive handle="olive" firstName="Olive" isPublic />)

    expect(screen.getByRole('heading', { name: /nice, olive/i })).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: 'Copy link' }))
    expect(writeText).toHaveBeenCalledWith(`${window.location.origin}/olive`)
    expect(await screen.findByRole('button', { name: 'Copied' })).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Share on X' }).getAttribute('href')).toContain('x.com/intent/post')
    expect(screen.getByRole('link', { name: /set up an agent/i })).toHaveAttribute('href', '/agents')
  })

  it('offers to go public instead of sharing a private profile', () => {
    render(<WelcomeLive handle="olive" isPublic={false} />)

    expect(screen.queryByRole('link', { name: 'Share on X' })).not.toBeInTheDocument()
    expect(screen.getByText(/only you can see this page/i)).toBeInTheDocument()
    expect(screen.getByText('Make it public')).toBeInTheDocument()
  })
})
