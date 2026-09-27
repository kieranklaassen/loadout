import { render, screen } from '@testing-library/react'
import type { ReactNode } from 'react'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import type { CurrentUser, SharedProps } from '../../types'
import NotFound from './not_found'

const { page } = vi.hoisted(() => ({ page: { props: {} as Partial<SharedProps>, url: '/dee' } }))

vi.mock('@inertiajs/react', () => ({
  Head: ({ title }: { title: string }) => <title>{title}</title>,
  Link: ({ href, children, ...rest }: { href: string; children: ReactNode }) => (
    <a href={href} {...rest}>
      {children}
    </a>
  ),
  router: { delete: vi.fn() },
  usePage: () => page,
}))

const member: CurrentUser = {
  id: 1,
  name: 'Eli Outside',
  handle: 'eli',
  avatar_url: null,
  every_member: false,
  admin: false,
  visibility: 'link',
  email_verified: false,
  onboarded: true,
}

const signIn = (user: CurrentUser | null) => {
  page.props = { current_user: user, flash: {}, public_host: 'loadout.every.to' }
}

beforeEach(() => signIn(null))

describe('Not found', () => {
  it('says the page is not there or not shared, without saying which', () => {
    render(<NotFound />)

    expect(screen.getByRole('heading', { level: 1, name: 'Page not found' })).toBeInTheDocument()
    expect(screen.getByText('There is no page at this address, or it is not shared with you.')).toBeInTheDocument()
    expect(document.title).toBe('Page not found')
  })

  it('offers a signed-out visitor sign-in for a page shared with the Every team', () => {
    render(<NotFound />)

    expect(screen.getByRole('link', { name: 'If this was shared with the Every team, sign in' })).toHaveAttribute('href', '/session/new')
  })

  it('does not ask someone who is signed in to sign in', () => {
    signIn(member)
    render(<NotFound />)

    expect(screen.queryByRole('link', { name: /sign in/i })).not.toBeInTheDocument()
  })

  it('always leads back to Home', () => {
    render(<NotFound />)

    expect(screen.getByRole('link', { name: 'Go to Home' })).toHaveAttribute('href', '/')
  })
})
