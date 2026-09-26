import { render, screen } from '@testing-library/react'
import type { ReactNode } from 'react'
import { describe, expect, it, vi } from 'vitest'
import { PeopleStack, RankRow } from './map_rank'

vi.mock('@inertiajs/react', () => ({
  Link: ({ href, children, ...rest }: { href: string; children: ReactNode }) => (
    <a href={href} {...rest}>
      {children}
    </a>
  ),
  router: { patch: vi.fn() },
  usePage: () => ({ props: { current_user: { id: 1 } } }),
}))

const cursor = { slug: 'cursor', name: 'Cursor', maker: 'Anysphere', hue: 220, monogram: 'Cu' }
const ana = { handle: 'ana', name: 'Ana Every', avatar_url: null }
const dee = { handle: 'dee', name: 'Dee Every', avatar_url: null }

describe('PeopleStack', () => {
  it('names public profiles and folds the rest into "and N others"', () => {
    render(<PeopleStack people={[ana, dee]} othersCount={3} />)

    expect(screen.getByRole('link', { name: 'Ana Every' })).toHaveAttribute('href', '/ana')
    expect(screen.getByText('and 3 others')).toBeInTheDocument()
  })

  it('says when everyone is private', () => {
    render(<PeopleStack people={[]} othersCount={2} />)

    expect(screen.getByText('2 people, all private')).toBeInTheDocument()
  })
})

describe('RankRow', () => {
  it('shows the count, share, and a one-click add', () => {
    render(
      <ol>
        <RankRow
          rank={{ item: cursor, count: 5, share: 1, people: [ana], others_count: 4, in_loadout: false }}
          position={1}
          category="coding"
        />
      </ol>,
    )

    expect(screen.getByText('Cursor')).toBeInTheDocument()
    expect(screen.getByText('· 100%')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Add Cursor to your loadout' })).toBeInTheDocument()
  })
})
