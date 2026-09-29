import { fireEvent, render, screen, within } from '@testing-library/react'
import type { ReactNode } from 'react'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import type { CurrentUser, SharedProps } from '../types'
import AppShell from './app_shell'

const { deleteSession, page } = vi.hoisted(() => ({
  deleteSession: vi.fn(),
  page: { props: {} as Partial<SharedProps>, url: '/' },
}))

vi.mock('@inertiajs/react', () => ({
  Link: ({ href, children, ...rest }: { href: string; children: ReactNode }) => (
    <a href={href} {...rest}>
      {children}
    </a>
  ),
  router: { delete: deleteSession },
  usePage: () => page,
}))

const member: CurrentUser = {
  id: 1,
  name: 'Ana Every',
  handle: 'ana',
  avatar_url: null,
  every_member: true,
  admin: false,
  visibility: 'only_me',
  email_verified: true,
  onboarded: true,
}

const signIn = (user: CurrentUser | null, extra: Partial<SharedProps> = {}, url = '/') => {
  page.props = { current_user: user, flash: {}, ...extra }
  page.url = url
}

beforeEach(() => {
  deleteSession.mockClear()
  signIn(null)
})

describe('AppShell header', () => {
  it('shows the four nav links and the account menu for a signed-in member', () => {
    signIn(member)
    render(<AppShell>content</AppShell>)

    const nav = screen.getByRole('navigation', { name: 'Main' })
    expect(within(nav).getAllByRole('link').map((link) => [link.textContent, link.getAttribute('href')])).toEqual([
      ['Home', '/'],
      ['Your toolbox', '/toolbox/edit'],
      ['Agents', '/agents'],
      ['Settings', '/settings'],
    ])
    expect(screen.getByRole('button', { name: 'Account menu' })).toBeInTheDocument()
    expect(screen.queryByRole('link', { name: 'Sign in' })).not.toBeInTheDocument()
  })

  it('marks the current page in the nav, with Kind pages counting as Home', () => {
    signIn(member, {}, '/toolbox/edit')
    const { unmount } = render(<AppShell>content</AppShell>)
    expect(screen.getByRole('link', { name: 'Your toolbox' })).toHaveAttribute('aria-current', 'page')
    expect(screen.getByRole('link', { name: 'Home' })).not.toHaveAttribute('aria-current')
    unmount()

    signIn(member, {}, '/kinds/coding?show=team')
    render(<AppShell>content</AppShell>)
    expect(screen.getByRole('link', { name: 'Home' })).toHaveAttribute('aria-current', 'page')
  })

  it('shows Sign in and no nav for a visitor', () => {
    render(<AppShell>content</AppShell>)

    expect(screen.getByRole('link', { name: 'Sign in' })).toHaveAttribute('href', '/session/new')
    expect(screen.queryByRole('navigation', { name: 'Main' })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Account menu' })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Menu' })).not.toBeInTheDocument()
  })

  it('renders the Home search slot inside the header', () => {
    signIn(member)
    render(<AppShell search={<input type="search" aria-label="Search tools, models and people" />}>content</AppShell>)

    expect(within(screen.getByRole('banner')).getByRole('searchbox', { name: /search tools/i })).toBeInTheDocument()
  })

  it('keeps the search slot for visitors too', () => {
    render(<AppShell search={<input type="search" aria-label="Search" />}>content</AppShell>)

    expect(within(screen.getByRole('banner')).getByRole('searchbox')).toBeInTheDocument()
  })

  it('offers a Menu button for phone width that opens and closes the nav', () => {
    signIn(member)
    render(<AppShell>content</AppShell>)

    const menu = screen.getByRole('button', { name: 'Menu' })
    const panel = document.getElementById('site-menu') as HTMLElement
    expect(menu).toHaveClass('md:hidden')
    expect(menu).toHaveAttribute('aria-controls', 'site-menu')
    expect(menu).toHaveAttribute('aria-expanded', 'false')
    expect(panel).toHaveClass('hidden', 'md:contents')
    expect(panel).toContainElement(screen.getByRole('navigation', { name: 'Main' }))

    fireEvent.click(menu)
    expect(menu).toHaveAttribute('aria-expanded', 'true')
    expect(panel).toHaveClass('flex')
    expect(panel).not.toHaveClass('hidden')

    fireEvent.click(menu)
    expect(menu).toHaveAttribute('aria-expanded', 'false')
  })

  it('reveals the search slot with the Menu button on phones', () => {
    render(<AppShell search={<input type="search" aria-label="Search" />}>content</AppShell>)

    const panel = document.getElementById('site-menu') as HTMLElement
    expect(panel).toContainElement(screen.getByRole('searchbox'))
    expect(screen.getByRole('button', { name: 'Menu' })).toHaveAttribute('aria-controls', 'site-menu')
  })

  it('trims the header for the pages without navigation', () => {
    signIn(member)
    const { unmount } = render(<AppShell header="account">content</AppShell>)
    expect(screen.queryByRole('navigation', { name: 'Main' })).not.toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Account menu' })).toBeInTheDocument()
    unmount()

    render(<AppShell header="logo">content</AppShell>)
    expect(screen.queryByRole('button', { name: 'Account menu' })).not.toBeInTheDocument()
    expect(screen.queryByRole('link', { name: 'Sign in' })).not.toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Every Toolbox home' })).toHaveAttribute('href', '/')
  })
})

describe('AppShell account menu', () => {
  it('opens with the profile link and signs out', () => {
    signIn(member)
    render(<AppShell>content</AppShell>)

    expect(screen.queryByRole('menu')).not.toBeInTheDocument()
    fireEvent.click(screen.getByRole('button', { name: 'Account menu' }))

    expect(screen.getByRole('menuitem', { name: 'Your profile' })).toHaveAttribute('href', '/ana')
    expect(screen.queryByRole('menuitem', { name: 'Catalog review' })).not.toBeInTheDocument()
    fireEvent.click(screen.getByRole('menuitem', { name: 'Sign out' }))
    expect(deleteSession).toHaveBeenCalledWith('/session')
  })

  it('lists catalog review for admins only', () => {
    signIn({ ...member, admin: true })
    render(<AppShell>content</AppShell>)
    fireEvent.click(screen.getByRole('button', { name: 'Account menu' }))

    expect(screen.getByRole('menuitem', { name: 'Catalog review' })).toHaveAttribute('href', '/admin/catalog_items')
  })
})

describe('AppShell footer and flash', () => {
  it('renders the footer lockup with the host from public_host', () => {
    signIn(null, { public_host: 'toolbox.example.com' })
    render(<AppShell>content</AppShell>)

    const footer = screen.getByRole('contentinfo')
    expect(within(footer).getByText('toolbox.example.com')).toBeInTheDocument()
    expect(within(footer).getByText('Toolbox')).toBeInTheDocument()
    expect(within(footer).getByAltText('Every')).toBeInTheDocument()
    expect(footer).not.toHaveTextContent('every.to/toolbox')
  })

  it('falls back to toolbox.every.to when the server sends no public_host', () => {
    render(<AppShell>content</AppShell>)

    expect(within(screen.getByRole('contentinfo')).getByText('toolbox.every.to')).toBeInTheDocument()
  })

  it('shows flash messages as a status or an alert', () => {
    signIn(null, { flash: { alert: 'That link has expired.' } })
    const { unmount } = render(<AppShell>content</AppShell>)
    expect(screen.getByRole('alert')).toHaveTextContent('That link has expired.')
    unmount()

    signIn(null, { flash: { notice: 'Saved.' } })
    render(<AppShell>content</AppShell>)
    expect(screen.getByRole('status')).toHaveTextContent('Saved.')
  })

  it('renders its children in main', () => {
    render(<AppShell>page body</AppShell>)

    expect(within(screen.getByRole('main')).getByText('page body')).toBeInTheDocument()
  })
})
