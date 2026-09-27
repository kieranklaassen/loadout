import { render, screen, within } from '@testing-library/react'
import type { ComponentProps, ReactNode } from 'react'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { codingKind, codingRow, heroData, homeFilters, launch, musicKind, personData, writingKind } from '../../test/home_fixtures'
import { claudeCodeMark, cursorMark, opusMark } from '../../test/picker_fixtures'
import type { CurrentUser, SharedProps } from '../../types'
import Home from './index'

const { page } = vi.hoisted(() => ({ page: { props: {} as Partial<SharedProps>, url: '/' } }))

vi.mock('@inertiajs/react', () => ({
  Head: ({ title }: { title: string }) => <title>{title}</title>,
  Link: ({ href, children, preserveScroll, preserveState, ...rest }: { href: string; children: ReactNode; preserveScroll?: boolean; preserveState?: boolean }) => (
    <a href={href} {...rest}>
      {children}
    </a>
  ),
  router: { get: vi.fn(), delete: vi.fn() },
  usePage: () => page,
}))

type Props = ComponentProps<typeof Home>

const member: CurrentUser = {
  id: 1,
  name: 'Dee Every',
  handle: 'dee',
  avatar_url: null,
  every_member: true,
  admin: false,
  visibility: 'team',
  email_verified: true,
  onboarded: true,
}

const signIn = (user: CurrentUser | null) => {
  page.props = { current_user: user, flash: {}, public_host: 'loadout.every.to' }
}

const props = (overrides: Partial<Props> = {}): Props => ({
  filters: homeFilters(),
  people: [{ handle: 'ana', name: 'Ana Every' }],
  notice: null,
  private_picks: false,
  empty_reason: null,
  launches: [launch()],
  hero: heroData(),
  rows: [codingRow()],
  overall: { tools: [{ item: claudeCodeMark, count: { n: 5, of: 6 } }], models: [{ item: opusMark, count: { n: 4, of: 6 } }] },
  person: null,
  cta: { label: 'Join Every', href: 'https://every.to' },
  all_vibe_checks_url: 'https://checks.every.to',
  ...overrides,
})

beforeEach(() => signIn(null))

describe('Home', () => {
  it('leads with the title and the hero caption, then launches and what we use', () => {
    render(<Home {...props()} />)

    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('The AI tools Every uses')
    expect(document.title).toBe('The AI tools Every uses')
    expect(screen.getByRole('heading', { level: 2, name: 'Latest model launches' })).toBeInTheDocument()
    expect(screen.getByRole('link', { name: /All Vibe Checks/ })).toHaveAttribute('href', 'https://checks.every.to')
    expect(screen.getByRole('heading', { level: 2, name: 'What we use' })).toBeInTheDocument()
    expect(screen.getByText('6 people ranked 30 picks', { exact: false })).toBeInTheDocument()
    expect(screen.getByRole('search')).toBeInTheDocument()
  })

  it('shows a launch with its Vibe Check link and marks the newest', () => {
    render(<Home {...props()} />)

    const launches = screen.getByRole('region', { name: 'Latest model launches' })
    expect(within(launches).getByRole('link', { name: 'Vibe Check for Claude Opus 5.5' })).toHaveAttribute('rel', 'noopener noreferrer')
    expect(within(launches).getByText('Newest')).toBeInTheDocument()
  })

  it('omits the launches section, heading and All Vibe Checks link, when no model qualifies', () => {
    render(<Home {...props({ launches: [] })} />)

    expect(screen.queryByRole('heading', { name: 'Latest model launches' })).not.toBeInTheDocument()
    expect(screen.queryByRole('link', { name: /All Vibe Checks/ })).not.toBeInTheDocument()
  })

  it('renders no hero without hero data', () => {
    const { container } = render(<Home {...props({ hero: null })} />)

    expect(container.querySelector('.hero')).toBeNull()
    expect(screen.queryByRole('figure')).not.toBeInTheDocument()
  })

  it('shows the What we use table by default and Overall top 10 when asked', () => {
    const { unmount } = render(<Home {...props()} />)
    expect(screen.getByRole('table')).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'By kind of work' })).toHaveAttribute('aria-current', 'page')
    unmount()

    render(<Home {...props({ filters: homeFilters({ overall: true }) })} />)
    expect(screen.queryByRole('table')).not.toBeInTheDocument()
    expect(screen.getByRole('region', { name: 'Tools' })).toHaveTextContent('5 of 6 use it')
    expect(screen.getByRole('link', { name: 'Overall top 10' })).toHaveAttribute('aria-current', 'page')
  })

  it('keeps a kind nobody ranked and one with no model in place', () => {
    const rows = [
      codingRow(),
      { category: writingKind, top_tool: null, top_model: null, ranked: { n: 0, of: 6 }, last_update_at: null, stale: false },
      codingRow({ category: musicKind, top_model: null }),
    ]
    render(<Home {...props({ rows })} />)

    expect(screen.getByText('Nobody has ranked this yet')).toBeInTheDocument()
    expect(screen.getByText('No model picked')).toBeInTheDocument()
  })

  it('offers the group and person filters with the current choices', () => {
    render(<Home {...props({ filters: homeFilters({ show: 'others' }) })} />)

    expect(screen.getByRole('radio', { name: 'Everyone else' })).toBeChecked()
    expect(screen.getByLabelText('Person')).toHaveValue('')
    expect(screen.getByRole('radio', { name: /Every subscribers/ })).toHaveAttribute('aria-disabled', 'true')
  })

  it('states the notice when Every subscribers fell back to the team', () => {
    render(<Home {...props({ notice: 'Every subscribers are not available yet, so this shows the Every team.' })} />)

    expect(screen.getByRole('status')).toHaveTextContent('Every subscribers are not available yet')
  })

  it('shows search results under the header once they arrive', () => {
    const search = { query: 'cursor', people: [], items: [{ kind: 'tool' as const, item: cursorMark, kinds: [{ category: codingKind, count: { n: 3, of: 6 } }] }] }
    render(<Home {...props({ search, filters: homeFilters({ q: 'cursor' }) })} />)

    const results = screen.getByRole('region', { name: 'Search results' })
    expect(within(results).getByText('Cursor')).toBeInTheDocument()
    expect(within(results).getByText('3 of 6')).toBeInTheDocument()
  })
})

describe('Home empty population', () => {
  const empty = (overrides: Partial<Props> = {}) =>
    props({ empty_reason: 'nobody_shared', hero: null, rows: [], launches: [launch({ adoption: { n: 0, of: 0 }, mostly_in: null })], ...overrides })

  it('says nobody has shared and offers Join Every, with no hero data and no zero-of-zero', () => {
    const { container } = render(<Home {...empty()} />)

    expect(screen.getByRole('heading', { name: 'Nobody has shared a loadout yet' })).toBeInTheDocument()
    expect(screen.getAllByRole('link', { name: 'Join Every' })).toHaveLength(1)
    expect(container.querySelector('.hero')).toBeNull()
    expect(screen.queryByRole('table')).not.toBeInTheDocument()
    expect(screen.queryByRole('navigation', { name: 'Ranking view' })).not.toBeInTheDocument()
    expect(container.textContent).not.toMatch(/\bof 0\b/)
  })

  it('offers a signed-in member to rank their first tools', () => {
    signIn(member)
    render(<Home {...empty({ cta: { label: 'Rank your first tools', href: '/loadout/edit' } })} />)

    expect(screen.getByRole('heading', { name: 'Nobody has shared a loadout yet' })).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Rank your first tools' })).toHaveAttribute('href', '/loadout/edit')
    expect(screen.queryByRole('link', { name: 'Join Every' })).not.toBeInTheDocument()
  })
})

describe('Home call to action by viewer', () => {
  it('asks a visitor to join Every at the bottom', () => {
    render(<Home {...props()} />)

    const bottom = screen.getByRole('region', { name: 'Join Every' })
    expect(within(bottom).getByRole('link', { name: 'Join Every' })).toHaveAttribute('href', 'https://every.to')
  })

  it('asks a member with no picks to rank their first tools', () => {
    signIn(member)
    render(<Home {...props({ cta: { label: 'Rank your first tools', href: '/loadout/edit' } })} />)

    expect(screen.getByRole('link', { name: 'Rank your first tools' })).toHaveAttribute('href', '/loadout/edit')
    expect(screen.queryByRole('link', { name: 'Join Every' })).not.toBeInTheDocument()
  })

  it('shows no call to action to a member who has picks', () => {
    signIn(member)
    render(<Home {...props({ cta: null })} />)

    expect(screen.queryByRole('region', { name: /Join Every|Add your loadout/ })).not.toBeInTheDocument()
  })
})

describe('Home viewer notes', () => {
  it('tells a member who shares privately that the counts include their picks', () => {
    signIn({ ...member, visibility: 'only_me' })
    render(<Home {...props({ private_picks: true, cta: null })} />)

    expect(screen.getByText('These counts include your private picks. Only you can see them.')).toBeInTheDocument()
  })

  it('tells a member who shares with anyone with the link that they are listed and searchable', () => {
    signIn({ ...member, visibility: 'link' })
    render(<Home {...props({ cta: null })} />)

    expect(screen.getByText('You share with anyone with the link, so you are listed here and in search.')).toBeInTheDocument()
  })

  it('says nothing about visibility to a visitor', () => {
    render(<Home {...props()} />)

    expect(screen.queryByText(/private picks|listed here/)).not.toBeInTheDocument()
  })
})

describe('Home person view', () => {
  const view = (overrides: Partial<Props> = {}) =>
    props({ filters: homeFilters({ person: 'dan' }), person: personData(), hero: null, ...overrides })

  it('is the same page for one person: their name in the title, their picks per kind, no hero, launches or Overall toggle', () => {
    const { container } = render(<Home {...view()} />)

    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('The AI tools Dan uses')
    expect(screen.getByText('Dan ranked 2 of 3 kinds of work', { exact: false })).toBeInTheDocument()
    expect(screen.getByRole('link', { name: "See Dan's full page" })).toHaveAttribute('href', '/dan')
    expect(screen.getByRole('heading', { level: 2, name: 'What Dan uses' })).toBeInTheDocument()
    expect(screen.getByRole('columnheader', { name: "Dan's tools (the app)" })).toBeInTheDocument()
    expect(container.querySelector('.hero')).toBeNull()
    expect(screen.queryByRole('heading', { name: 'Latest model launches' })).not.toBeInTheDocument()
    expect(screen.queryByRole('navigation', { name: 'Ranking view' })).not.toBeInTheDocument()
  })

  it('shows "New in Dan\'s loadout" only when a launched model is in it', () => {
    const { unmount } = render(<Home {...view()} />)
    expect(screen.getByText("New in Dan's loadout")).toBeInTheDocument()
    unmount()

    render(<Home {...view({ person: personData({ new_in_loadout: [] }) })} />)
    expect(screen.queryByText("New in Dan's loadout")).not.toBeInTheDocument()
  })

  it('selects the person in the filter', () => {
    render(<Home {...view({ people: [{ handle: 'dan', name: 'Dan' }] })} />)

    expect(screen.getByLabelText('Person')).toHaveValue('dan')
  })

  it('tells the owner that only they can see their own page', () => {
    signIn({ ...member, handle: 'dan', visibility: 'only_me' })
    render(<Home {...view({ private_picks: true })} />)

    expect(screen.getByText('Only you can see this page.')).toBeInTheDocument()
  })
})
