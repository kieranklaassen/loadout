import { render, screen, within } from '@testing-library/react'
import type { ReactNode } from 'react'
import { describe, expect, it, vi } from 'vitest'
import { dan, kieran, listing, rob } from '../../test/kind_fixtures'
import { claudeCodeMark, cursorMark } from '../../test/picker_fixtures'
import RankedList from './ranked_list'

vi.mock('@inertiajs/react', () => ({
  Link: ({ href, children, ...rest }: { href: string; children: ReactNode }) => (
    <a href={href} {...rest}>
      {children}
    </a>
  ),
}))

const renderList = (listings = [listing(claudeCodeMark, { n: 4, of: 6 }, { 1: [kieran, dan], 3: [rob] }), listing(cursorMark, { n: 1, of: 6 }, { 2: [dan] })]) =>
  render(<RankedList title="Tools" listings={listings} empty="No tools ranked yet" />)

describe('RankedList', () => {
  it('numbers the items in the order given, with N of M', () => {
    renderList()

    const [first, second] = screen.getAllByRole('listitem')
    expect(first).toHaveTextContent('1Claude Code')
    expect(first).toHaveTextContent('4 of 6 use it')
    expect(second).toHaveTextContent('2Cursor')
    expect(second).toHaveTextContent('1 of 6 use it')
  })

  it('writes who ranked it at each rank, skipping ranks nobody used', () => {
    renderList()

    const [first, second] = screen.getAllByRole('listitem')
    expect(first).toHaveTextContent('1st for Kieran, Dan; 3rd for Rob')
    expect(first).not.toHaveTextContent('2nd')
    expect(second).toHaveTextContent('2nd for Dan')
  })

  it('counts people it may not name as others, never by rank and never as a link', () => {
    renderList([listing(claudeCodeMark, { n: 3, of: 6 }, { 1: [kieran] }, 2), listing(cursorMark, { n: 1, of: 6 }, {}, 1)])

    const [first, second] = screen.getAllByRole('listitem')
    expect(first).toHaveTextContent('1st for Kieran · and 2 others')
    expect(within(first).getAllByRole('link')).toHaveLength(1)
    expect(second).toHaveTextContent('1 person, not listed')
    expect(within(second).queryByRole('link')).not.toBeInTheDocument()
  })

  it('links every name to that person, wherever they appear', () => {
    renderList()

    const links = within(screen.getAllByRole('listitem')[0]).getAllByRole('link')
    expect(links.map((link) => [link.textContent, link.getAttribute('href')])).toEqual([
      ['Kieran', '/kieran'],
      ['Dan', '/dan'],
      ['Rob', '/rob'],
    ])
  })

  it('marks only the first row yellow', () => {
    renderList()

    const [first, second] = screen.getAllByRole('listitem')
    expect(within(first).getByText('1')).toHaveClass('text-yellow')
    expect(within(second).getByText('2')).not.toHaveClass('text-yellow')
  })

  it('says so when the list is empty', () => {
    renderList([])

    expect(screen.queryByRole('list')).not.toBeInTheDocument()
    expect(screen.getByText('No tools ranked yet')).toBeInTheDocument()
    expect(screen.getByRole('region', { name: 'Tools' })).toBeInTheDocument()
  })
})
