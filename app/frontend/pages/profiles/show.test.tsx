import { act, fireEvent, render, screen, within } from '@testing-library/react'
import type { ReactNode } from 'react'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { rankedPick } from '../../test/picker_fixtures'
import { profileProps, yourPicks } from '../../test/profile_fixtures'
import type { CurrentUser, SharedProps } from '../../types'
import ProfileShow from './show'

const { page } = vi.hoisted(() => ({ page: { props: {} as Partial<SharedProps>, url: '/dan' } }))

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

const member = (overrides: Partial<CurrentUser> = {}): CurrentUser => ({
  id: 1,
  name: 'Dee Every',
  handle: 'dee',
  avatar_url: null,
  every_member: true,
  admin: false,
  visibility: 'team',
  email_verified: true,
  onboarded: true,
  ...overrides,
})

const signIn = (user: CurrentUser | null) => {
  page.props = { current_user: user, flash: {}, public_host: 'toolbox.every.to' }
}

const writeText = vi.fn().mockResolvedValue(undefined)

beforeEach(() => {
  signIn(null)
  writeText.mockClear()
  Object.defineProperty(navigator, 'clipboard', { value: { writeText }, configurable: true })
})

describe('Profile page', () => {
  it('names the person, shows their one-line bio and says how many kinds they ranked', () => {
    render(<ProfileShow {...profileProps()} />)

    expect(screen.getByRole('heading', { level: 1, name: 'Dan Every' })).toBeInTheDocument()
    expect(screen.getByText('Claude Code for everything that ships.')).toBeInTheDocument()
    expect(screen.getByRole('heading', { level: 2, name: "Dan's toolbox" })).toBeInTheDocument()
    expect(screen.getByText('2 of 3 ranked')).toBeInTheDocument()
    expect(document.title).toBe("Dan Every's toolbox")
  })

  it('leaves out the bio when there is none', () => {
    const { container } = render(<ProfileShow {...profileProps({ bio: null })} />)

    expect(container.querySelector('section[aria-label="Dan Every"] p')).toBeNull()
  })

  it('has a row for each kind they ranked and one plain line naming the rest', () => {
    render(<ProfileShow {...profileProps()} />)

    expect(screen.getAllByRole('rowheader').map((header) => header.textContent)).toEqual(['Coding', 'Writing'])
    expect(screen.getByText('Not ranked yet: Music')).toBeInTheDocument()
  })

  it('names every unranked kind, in order, and drops the line once all are ranked', () => {
    const props = profileProps()
    const kinds = [...props.kinds, { ...props.kinds[2], category: { slug: 'video', name: 'Video', blurb: '' } }]
    const { unmount } = render(<ProfileShow {...props} kinds={kinds} />)
    expect(screen.getByText('Not ranked yet: Music, Video')).toBeInTheDocument()
    unmount()

    render(<ProfileShow {...props} kinds={props.kinds.map((kind) => ({ ...kind, picks: kind.picks.length ? kind.picks : [rankedPick()] }))} ranked_count={3} />)
    expect(screen.queryByText(/Not ranked yet/)).not.toBeInTheDocument()
  })

  it('shows no team notes, recent changes or pick notes', () => {
    const { container } = render(<ProfileShow {...profileProps()} />)

    expect(container.textContent).not.toMatch(/team uses|team's most used|recent|switched|new in/i)
  })

  it('copies the profile link', async () => {
    render(<ProfileShow {...profileProps()} />)

    await act(async () => {
      fireEvent.click(screen.getByRole('button', { name: 'Copy link' }))
    })

    expect(writeText).toHaveBeenCalledWith('https://toolbox.every.to/dan')
    expect(screen.getByRole('button', { name: 'Link copied' })).toBeInTheDocument()
    expect(screen.queryByRole('link', { name: /share on x/i })).not.toBeInTheDocument()
  })
})

describe('Profile page without picks', () => {
  const empty = () => profileProps({ ranked_count: 0, kinds: profileProps().kinds.map((kind) => ({ ...kind, picks: [] })) })

  it('says the person has not ranked anything, with no table and no unranked line', () => {
    render(<ProfileShow {...empty()} />)

    expect(screen.getByText('Dan has not ranked any tools yet.')).toBeInTheDocument()
    expect(screen.getByText('0 of 3 ranked')).toBeInTheDocument()
    expect(screen.queryByRole('table')).not.toBeInTheDocument()
    expect(screen.queryByText(/Not ranked yet/)).not.toBeInTheDocument()
    expect(screen.queryByRole('link', { name: 'Rank your first tools' })).not.toBeInTheDocument()
  })

  it('invites the owner to rank their first tools', () => {
    signIn(member({ handle: 'dan', name: 'Dan Every' }))
    render(<ProfileShow {...empty()} />)

    expect(screen.getByRole('link', { name: 'Rank your first tools' })).toHaveAttribute('href', '/toolbox/edit')
  })
})

describe('Compare with mine', () => {
  const comparable = () => profileProps({ viewer_can_compare: true, you: yourPicks })
  const toggle = () => screen.getByRole('button', { name: 'Compare with mine' })

  it('is not offered to a visitor, a member with nothing ranked or the owner', () => {
    render(<ProfileShow {...profileProps({ viewer_can_compare: false, you: {} })} />)

    expect(screen.queryByRole('button', { name: 'Compare with mine' })).not.toBeInTheDocument()
  })

  it('is off until pressed: no You column, and the button says so', () => {
    signIn(member())
    render(<ProfileShow {...comparable()} />)

    expect(toggle()).toHaveAttribute('aria-pressed', 'false')
    expect(screen.queryByRole('columnheader', { name: 'You' })).not.toBeInTheDocument()
  })

  it('adds a You column with the viewer\'s first tool and model, and removes it when pressed again', () => {
    signIn(member())
    render(<ProfileShow {...comparable()} />)

    fireEvent.click(toggle())

    expect(toggle()).toHaveAttribute('aria-pressed', 'true')
    expect(screen.getAllByRole('columnheader').map((header) => header.textContent)).toEqual(['Kind of work', 'Tool', 'Model', 'You'])
    const coding = screen.getByRole('rowheader', { name: 'Coding' }).closest('tr') as HTMLElement
    const you = within(coding).getAllByRole('cell')[2]
    expect(you).toHaveTextContent('Cursor')
    expect(you).toHaveTextContent('GPT-6 Astra')

    fireEvent.click(toggle())

    expect(toggle()).toHaveAttribute('aria-pressed', 'false')
    expect(screen.queryByRole('columnheader', { name: 'You' })).not.toBeInTheDocument()
  })

  it('marks a kind the viewer has not ranked, and adds no kind only the viewer ranked', () => {
    signIn(member())
    render(<ProfileShow {...comparable()} />)

    fireEvent.click(toggle())

    const writing = screen.getByRole('rowheader', { name: 'Writing' }).closest('tr') as HTMLElement
    expect(within(writing).getAllByRole('cell')[2]).toHaveTextContent('Not ranked')
    expect(screen.queryByRole('rowheader', { name: 'Video' })).not.toBeInTheDocument()
    expect(screen.getByText('Not ranked yet: Music')).toBeInTheDocument()
  })

  it('keeps Copy link beside it', () => {
    signIn(member())
    render(<ProfileShow {...comparable()} />)

    expect(screen.getByRole('button', { name: 'Copy link' })).toBeInTheDocument()
  })
})
