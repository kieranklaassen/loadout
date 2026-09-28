import { render, screen, within } from '@testing-library/react'
import type { ComponentProps, ReactNode } from 'react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { codingKind, eras, models, setups, takes, tools } from '../../test/kind_fixtures'
import type { SharedProps } from '../../types'
import KindPage from './show'

const { page } = vi.hoisted(() => ({ page: { props: {} as Partial<SharedProps>, url: '/kinds/coding' } }))

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

type Props = ComponentProps<typeof KindPage>

const props = (overrides: Partial<Props> = {}): Props => ({
  filters: { show: 'team' },
  notice: null,
  category: { ...codingKind, blurb: 'Writing, reviewing, and shipping code.' },
  ranked: { n: 4, of: 6 },
  tools,
  models,
  setups,
  takes,
  last_update_at: '2026-09-25T12:00:00Z',
  eras: null,
  cta: { label: 'Rank your coding picks', href: '/toolbox/edit?kind=coding' },
  ...overrides,
})

beforeEach(() => {
  vi.useFakeTimers({ toFake: ['Date'] })
  vi.setSystemTime(new Date('2026-09-27T12:00:00Z'))
  page.props = { current_user: null, flash: {}, public_host: 'toolbox.every.to' }
})

afterEach(() => vi.useRealTimers())

describe('Kind page', () => {
  it('leads with the kind, K of M ranked it, when it was last updated and the call to action', () => {
    render(<KindPage {...props()} />)

    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('Coding')
    expect(document.title).toBe('Coding on Toolbox')
    expect(screen.getByText(/most recently/)).toHaveTextContent('Writing, reviewing, and shipping code. 4 of 6 ranked it, most recently 2 days ago.')
    expect(screen.getByRole('link', { name: 'Rank your coding picks' })).toHaveAttribute('href', '/toolbox/edit?kind=coding')
  })

  it('links back to Home in the group being shown', () => {
    const { unmount } = render(<KindPage {...props()} />)
    expect(screen.getByRole('link', { name: /The AI tools Every uses/ })).toHaveAttribute('href', '/')
    unmount()

    render(<KindPage {...props({ filters: { show: 'others' } })} />)
    expect(screen.getByRole('link', { name: /The AI tools Every uses/ })).toHaveAttribute('href', '/?show=others')
  })

  it('switches SHOW with links that keep the kind and mark the group being shown', () => {
    const { unmount } = render(<KindPage {...props()} />)
    const toggle = screen.getByRole('navigation', { name: 'Show' })
    expect(within(toggle).getByRole('link', { name: 'Every team' })).toHaveAttribute('aria-current', 'page')
    expect(within(toggle).getByRole('link', { name: 'Every team' })).toHaveAttribute('href', '/kinds/coding')
    expect(within(toggle).getByRole('link', { name: 'Everyone else' })).toHaveAttribute('href', '/kinds/coding?show=others')
    expect(within(toggle).getByRole('link', { name: 'Everyone else' })).not.toHaveAttribute('aria-current')
    unmount()

    render(<KindPage {...props({ filters: { show: 'others' } })} />)
    expect(within(screen.getByRole('navigation', { name: 'Show' })).getByRole('link', { name: 'Everyone else' })).toHaveAttribute('aria-current', 'page')
  })

  it('shows tools and models as separate sections with N of M and the people at each rank', () => {
    render(<KindPage {...props()} />)

    const toolSection = screen.getByRole('region', { name: 'Tools' })
    const claudeCode = within(toolSection).getByText('Claude Code').closest('li') as HTMLElement
    expect(claudeCode).toHaveTextContent('3 of 6 use it')
    expect(claudeCode).toHaveTextContent('1st for Kieran, Dan; 2nd for Rob')
    expect(within(toolSection).getByText('Cursor').closest('li')).toHaveTextContent('2nd for Dan; 3rd for Kieran')
    expect(within(toolSection).queryByText('Claude Opus 5.5')).not.toBeInTheDocument()

    const modelSection = screen.getByRole('region', { name: 'Models' })
    expect(within(modelSection).getByText('Claude Opus 5.5').closest('li')).toHaveTextContent('3 of 6 use it')
    expect(within(modelSection).getByText('GPT-6 Astra').closest('li')).toHaveTextContent('2nd for Rob, Dan')
    expect(screen.getByRole('heading', { level: 2, name: 'What we use' })).toBeInTheDocument()
  })

  it('names people with links to their pages', () => {
    render(<KindPage {...props()} />)

    const claudeCode = within(screen.getByRole('region', { name: 'Tools' })).getByText('Claude Code').closest('li') as HTMLElement
    expect(within(claudeCode).getByRole('link', { name: 'Kieran' })).toHaveAttribute('href', '/kieran')
    expect(within(claudeCode).getByRole('link', { name: 'Rob' })).toHaveAttribute('href', '/rob')
  })

  it('lists how we set them up with tool, model, context, effort and N of M', () => {
    render(<KindPage {...props()} />)

    const section = screen.getByRole('region', { name: 'How we set them up' })
    const rows = within(section).getAllByRole('listitem')
    expect(rows).toHaveLength(3)
    expect(rows[0]).toHaveTextContent('Claude Code')
    expect(rows[0]).toHaveTextContent('Claude Opus 5.5')
    expect(rows[0]).toHaveTextContent('1M context')
    expect(rows[0]).toHaveTextContent('high effort')
    expect(rows[0]).toHaveTextContent('2 of 6')
    expect(rows[1]).toHaveTextContent('medium effort')
    expect(rows[1]).not.toHaveTextContent('context')
    expect(rows[2]).not.toHaveTextContent('effort')
  })

  it('omits setups when nobody picked a model', () => {
    render(<KindPage {...props({ setups: [], models: [] })} />)

    expect(screen.queryByRole('region', { name: 'How we set them up' })).not.toBeInTheDocument()
    expect(screen.getByText('Nobody has picked a model yet')).toBeInTheDocument()
  })

  it('shows takes as sign-in-gated Vibe Check link-outs, with no quotes', () => {
    render(<KindPage {...props()} />)

    const section = screen.getByRole('region', { name: 'Takes on these models' })
    const link = within(section).getByRole('link', { name: 'Vibe Check for Claude Opus 5.5' })
    expect(link).toHaveAttribute('href', 'https://checks.every.to/vibe-checks/claude-opus-5-5')
    expect(link).toHaveAttribute('target', '_blank')
    expect(link).toHaveAttribute('rel', 'noopener noreferrer')
    expect(link).toHaveTextContent(/^Vibe Check/)
    expect(section).toHaveTextContent('Sign-in required')
    expect(section.querySelector('blockquote, q')).toBeNull()
  })

  it('hides the takes section when there are none', () => {
    render(<KindPage {...props({ takes: [] })} />)

    expect(screen.queryByRole('region', { name: 'Takes on these models' })).not.toBeInTheDocument()
    expect(screen.queryByText(/Vibe Check/)).not.toBeInTheDocument()
  })

  it('shows What we used before only with eras, and marks the current one', () => {
    const { unmount } = render(<KindPage {...props()} />)
    expect(screen.queryByRole('heading', { name: 'What we used before' })).not.toBeInTheDocument()
    unmount()

    render(<KindPage {...props({ eras })} />)
    const section = screen.getByRole('region', { name: 'What we used before' })
    expect(within(section).getAllByRole('listitem')).toHaveLength(3)
    expect(within(section).getAllByText('Now')).toHaveLength(1)
    expect(section).toHaveTextContent('who was sharing')
  })

  it('shows the notice when a group is not available yet', () => {
    render(<KindPage {...props({ notice: 'Every subscribers are not available yet, so this shows the Every team.' })} />)

    expect(screen.getByRole('status')).toHaveTextContent('Every subscribers are not available yet')
  })

  it('shows an empty state instead of zero of zero when nobody ranked the kind', () => {
    const { container, unmount } = render(
      <KindPage {...props({ ranked: { n: 0, of: 6 }, tools: [], models: [], setups: [], takes: [], last_update_at: null })} />,
    )
    expect(screen.getByRole('heading', { level: 2, name: 'Nobody has ranked coding yet' })).toBeInTheDocument()
    expect(screen.queryByRole('region', { name: 'Tools' })).not.toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Rank your coding picks' })).toBeInTheDocument()
    expect(container).not.toHaveTextContent('0 of')
    unmount()

    const nobody = render(<KindPage {...props({ ranked: { n: 0, of: 0 }, tools: [], models: [], setups: [], takes: [], last_update_at: null })} />)
    expect(nobody.container).not.toHaveTextContent('0 of')
    expect(nobody.container).not.toHaveTextContent('most recently')
  })
})
