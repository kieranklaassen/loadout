import { render, screen } from '@testing-library/react'
import type { ReactNode } from 'react'
import { describe, expect, it, vi } from 'vitest'
import type { ChangeEvent, LoadoutCategory, ProfileDetail } from '../../types'
import ProfileShow, { changeSource } from './show'

vi.mock('@inertiajs/react', () => ({
  Head: () => null,
  Link: ({ href, children, ...rest }: { href: string; children: ReactNode }) => (
    <a href={href} {...rest}>
      {children}
    </a>
  ),
  router: { delete: vi.fn() },
  usePage: () => ({ props: { current_user: null, flash: {} } }),
}))

const profile: ProfileDetail = {
  handle: 'ana',
  name: 'Ana Every',
  avatar_url: null,
  bio: 'Writes code and essays.',
  every_member: true,
  public: true,
  url: 'https://loadout.every.to/ana',
  display_url: 'loadout.every.to/ana',
}

const cursor = { slug: 'cursor', name: 'Cursor', maker: 'Anysphere', hue: 220, monogram: 'Cu' }
const opus = { slug: 'claude-opus-5-5', name: 'Claude Opus 5.5', maker: 'Anthropic', hue: 18, monogram: 'O5' }

const categories: LoadoutCategory[] = [
  {
    slug: 'coding',
    name: 'Coding',
    blurb: 'Writing, reviewing, and shipping code.',
    entries: [
      { id: 1, category: 'coding', tool: cursor, model: opus, note: 'Fast and sharp.', primary: true },
      { id: 2, category: 'coding', tool: { ...cursor, slug: 'zed', name: 'Zed', monogram: 'Ze' }, model: null, note: null, primary: false },
    ],
  },
]

const changes: ChangeEvent[] = [
  {
    id: 9,
    sentence: 'Switched coding model from Claude Opus 5 to Claude Opus 5.5 in Cursor',
    action: 'switched',
    source: 'mcp',
    client_name: 'Claude Code',
    created_at: new Date().toISOString(),
  },
]

describe('Profile page', () => {
  it('shows the hero, the go-to pick, recent changes, and the call to action for visitors', () => {
    render(<ProfileShow profile={profile} categories={categories} recent_changes={changes} is_owner={false} />)

    expect(screen.getByRole('heading', { level: 1, name: 'Ana Every' })).toBeInTheDocument()
    expect(screen.getByText('loadout.every.to/ana')).toBeInTheDocument()
    expect(screen.getByTitle('Every member')).toHaveTextContent('Every')
    expect(screen.getByRole('heading', { level: 3, name: 'Cursor' })).toBeInTheDocument()
    expect(screen.getByText('“Fast and sharp.”')).toBeInTheDocument()
    expect(screen.getByText(/Switched coding model/)).toBeInTheDocument()
    expect(screen.getByText(/via Claude Code/)).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /copy link/i })).toBeInTheDocument()
    expect(screen.getByRole('link', { name: /make your own loadout/i })).toHaveAttribute('href', '/auth/every')
  })

  it('tells the owner a private profile is only visible to them', () => {
    render(<ProfileShow profile={{ ...profile, public: false }} categories={categories} recent_changes={[]} is_owner />)

    expect(screen.getByText(/only you can see this/i)).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /copy link/i })).not.toBeInTheDocument()
    expect(screen.queryByRole('link', { name: /make your own loadout/i })).not.toBeInTheDocument()
    expect(screen.getByRole('link', { name: /edit your loadout/i })).toHaveAttribute('href', '/loadout/edit')
  })

  it('invites an owner with no picks to start', () => {
    render(<ProfileShow profile={profile} categories={[]} recent_changes={[]} is_owner />)

    expect(screen.getByRole('heading', { name: /your loadout is empty/i })).toBeInTheDocument()
    expect(screen.getByRole('link', { name: /pick your tools/i })).toHaveAttribute('href', '/loadout/edit')
  })

  it('names the source of a change', () => {
    expect(changeSource({ source: 'web', client_name: null })).toBe('on the web')
    expect(changeSource({ source: 'mcp', client_name: 'Cursor' })).toBe('via Cursor')
    expect(changeSource({ source: 'webmcp', client_name: null })).toBe('via a browser agent')
  })
})
