import { act, fireEvent, render, screen } from '@testing-library/react'
import type { ReactNode } from 'react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { codingKind, homeFilters } from '../../test/home_fixtures'
import { claudeCodeMark, opusMark } from '../../test/picker_fixtures'
import { SearchField, SearchResults, useSearch, type SearchData } from './search_results'

const { get } = vi.hoisted(() => ({ get: vi.fn() }))

vi.mock('@inertiajs/react', () => ({
  Link: ({ href, children, ...rest }: { href: string; children: ReactNode }) => (
    <a href={href} {...rest}>
      {children}
    </a>
  ),
  router: { get },
}))

const found: SearchData = {
  query: 'claude',
  people: [{ handle: 'ana', name: 'Ana Every' }],
  items: [
    { kind: 'tool', item: claudeCodeMark, kinds: [{ category: codingKind, count: { n: 4, of: 6 } }] },
    { kind: 'model', item: opusMark, kinds: [{ category: codingKind, count: { n: 3, of: 6 } }] },
  ],
}

describe('SearchResults', () => {
  const results = (props: Partial<Parameters<typeof SearchResults>[0]>) =>
    render(<SearchResults query="claude" search={found} failed={false} show="team" {...props} />)

  it('renders nothing until something is typed', () => {
    const { container } = results({ query: '  ' })

    expect(container).toBeEmptyDOMElement()
  })

  it('asks for two characters when the query is shorter', () => {
    results({ query: 'c', search: undefined })

    expect(screen.getByText('Type at least 2 characters')).toBeInTheDocument()
  })

  it('groups people, tools and models, each hit with its kinds and N of M', () => {
    results({})

    expect(screen.getByRole('link', { name: 'Ana Every' })).toHaveAttribute('href', '/ana')
    const kind = screen.getAllByRole('link', { name: 'Coding' })
    expect(kind.map((link) => link.getAttribute('href'))).toEqual(['/kinds/coding', '/kinds/coding'])
    expect(screen.getByText('Claude Code')).toBeInTheDocument()
    expect(screen.getByText('4 of 6')).toBeInTheDocument()
    expect(screen.getByText('Claude Opus 5.5')).toBeInTheDocument()
    expect(screen.getByText('3 of 6')).toBeInTheDocument()
    expect(screen.getByText('People')).toBeInTheDocument()
    expect(screen.getByText('Tools')).toBeInTheDocument()
    expect(screen.getByText('Models')).toBeInTheDocument()
  })

  it('leaves out a group with no hits', () => {
    results({ search: { ...found, people: [], items: [found.items[0]] } })

    expect(screen.queryByText('People')).not.toBeInTheDocument()
    expect(screen.queryByText('Models')).not.toBeInTheDocument()
    expect(screen.getByText('Tools')).toBeInTheDocument()
  })

  it('carries the group being shown into the kind links', () => {
    results({ show: 'others' })

    expect(screen.getAllByRole('link', { name: 'Coding' })[0]).toHaveAttribute('href', '/kinds/coding?show=others')
  })

  it('says nothing matches when the search found nothing', () => {
    results({ search: { query: 'zzz', people: [], items: [] } })

    expect(screen.getByText('Nothing matches “zzz”')).toBeInTheDocument()
  })

  it('says the search is busy after a failed request, in place of results', () => {
    results({ failed: true })

    expect(screen.getByText('Search is busy, try again in a minute')).toBeInTheDocument()
    expect(screen.queryByText('People')).not.toBeInTheDocument()
  })

  it('shows nothing while the first answer is on its way', () => {
    const { container } = results({ search: undefined })

    expect(container.querySelector('p')).toBeNull()
  })
})

// A page-shaped harness for the hook: the field and the results share its state.
function Harness({ filters = homeFilters(), search }: { filters?: ReturnType<typeof homeFilters>; search?: SearchData }) {
  const { query, setQuery, failed, inputRef } = useSearch(filters)
  return (
    <>
      <input aria-label="Other field" />
      <SearchField value={query} onChange={setQuery} inputRef={inputRef} />
      <SearchResults query={query} search={search} failed={failed} show={filters.show} />
    </>
  )
}

describe('useSearch', () => {
  beforeEach(() => {
    vi.useFakeTimers()
    get.mockClear()
  })
  afterEach(() => vi.useRealTimers())

  const type = (value: string) => fireEvent.change(screen.getByRole('searchbox'), { target: { value } })
  const settle = () => act(() => vi.advanceTimersByTime(300))

  it('asks Home for the search prop only, keeping the URL and re-sending the filters', () => {
    render(<Harness filters={homeFilters({ show: 'others', person: 'eli' })} />)

    type('  cur ')
    expect(get).not.toHaveBeenCalled()
    settle()

    expect(get).toHaveBeenCalledTimes(1)
    expect(get).toHaveBeenCalledWith(
      '/',
      { show: 'others', person: 'eli', q: 'cur' },
      expect.objectContaining({ only: ['search'], preserveUrl: true, preserveState: true, preserveScroll: true, replace: true }),
    )
  })

  it('sends one request for a burst of typing', () => {
    render(<Harness />)

    type('cu')
    act(() => vi.advanceTimersByTime(100))
    type('cur')
    act(() => vi.advanceTimersByTime(100))
    type('curs')
    settle()

    expect(get).toHaveBeenCalledTimes(1)
    expect(get.mock.calls[0][1]).toMatchObject({ q: 'curs' })
  })

  it('does not search under two characters and shows the hint', () => {
    render(<Harness />)

    type('c')
    settle()

    expect(get).not.toHaveBeenCalled()
    expect(screen.getByText('Type at least 2 characters')).toBeInTheDocument()
  })

  it('handles a 429 or a network error inline and stops Inertia from opening its modal', () => {
    render(<Harness />)

    type('cursor')
    settle()
    const { onHttpException, onNetworkError } = get.mock.calls[0][2]

    let returned: unknown
    act(() => {
      returned = onHttpException({ status: 429 })
    })
    expect(returned).toBe(false)
    expect(screen.getByText('Search is busy, try again in a minute')).toBeInTheDocument()

    act(() => onNetworkError(new Error('offline')))
    expect(screen.getByText('Search is busy, try again in a minute')).toBeInTheDocument()

    act(() => get.mock.calls[0][2].onSuccess())
    expect(screen.queryByText('Search is busy, try again in a minute')).not.toBeInTheDocument()
  })

  it('searches again when the group changes under a typed query', () => {
    const { rerender } = render(<Harness />)
    type('cursor')
    settle()

    rerender(<Harness filters={homeFilters({ show: 'others' })} />)
    settle()

    expect(get).toHaveBeenCalledTimes(2)
    expect(get.mock.calls[1][1]).toEqual({ show: 'others', q: 'cursor' })
  })

  it('starts from the query in the URL', () => {
    render(<Harness filters={homeFilters({ q: 'opus' })} />)

    expect(screen.getByRole('searchbox')).toHaveValue('opus')
    settle()
    expect(get.mock.calls[0][1]).toMatchObject({ q: 'opus' })
  })

  it('focuses the field on "/" unless the reader is already typing somewhere', () => {
    render(<Harness />)

    fireEvent.keyDown(document.body, { key: '/' })
    expect(screen.getByRole('searchbox')).toHaveFocus()

    const other = screen.getByLabelText('Other field')
    other.focus()
    fireEvent.keyDown(other, { key: '/' })
    expect(other).toHaveFocus()
  })

  it('leaves "/" with a modifier alone', () => {
    render(<Harness />)

    fireEvent.keyDown(document.body, { key: '/', ctrlKey: true })

    expect(screen.getByRole('searchbox')).not.toHaveFocus()
  })

  it('clears the query on Escape', () => {
    render(<Harness search={found} />)
    type('claude')
    expect(screen.getByRole('region', { name: 'Search results' })).toBeInTheDocument()

    fireEvent.keyDown(screen.getByRole('searchbox'), { key: 'Escape' })

    expect(screen.getByRole('searchbox')).toHaveValue('')
    expect(screen.queryByRole('region', { name: 'Search results' })).not.toBeInTheDocument()
  })
})
