import { render, screen } from '@testing-library/react'
import type { ReactNode } from 'react'
import { describe, expect, it, vi } from 'vitest'
import Home from './index'

vi.mock('@inertiajs/react', () => ({
  Head: () => null,
  Link: ({ children, href, ...rest }: { children: ReactNode; href: string }) => (
    <a href={href} {...rest}>
      {children}
    </a>
  ),
}))

describe('Home page', () => {
  it('asks the question and offers Sign in with Every', () => {
    render(<Home />)

    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent(/what's in your ai loadout/i)
    expect(screen.getByRole('link', { name: /claim your link/i })).toHaveAttribute('href', '/auth/every')
  })

  it('shows the most recently updated public profile as the hero card', () => {
    render(
      <Home
        stats={{ members: 3, picks: 12, tools: 50 }}
        featured={[
          {
            handle: 'ana',
            name: 'Ana Every',
            avatar_url: null,
            picks: [{ category: 'Coding', tool: { slug: 'cursor', name: 'Cursor', maker: null, hue: 220, monogram: 'Cu' }, model: null }],
          },
        ]}
      />,
    )

    expect(screen.getByText('Ana Every').closest('a')).toHaveAttribute('href', '/ana')
    expect(screen.getByText(/tools in the catalog/)).toBeInTheDocument()
  })
})
