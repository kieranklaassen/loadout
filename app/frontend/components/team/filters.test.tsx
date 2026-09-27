import { fireEvent, render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import type { ReactNode } from 'react'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { homeFilters } from '../../test/home_fixtures'
import Filters, { homeHref, kindHref, ViewToggle } from './filters'

const { get } = vi.hoisted(() => ({ get: vi.fn() }))

vi.mock('@inertiajs/react', () => ({
  Link: ({ href, children, preserveScroll, preserveState, ...rest }: { href: string; children: ReactNode; preserveScroll?: boolean; preserveState?: boolean }) => (
    <a href={href} {...rest}>
      {children}
    </a>
  ),
  router: { get },
}))

const people = [
  { handle: 'ana', name: 'Ana Every' },
  { handle: 'dee', name: 'Dee Every' },
]

beforeEach(() => get.mockClear())

describe('homeHref and kindHref', () => {
  it('leave out the defaults', () => {
    expect(homeHref({ show: 'team' })).toBe('/')
    expect(homeHref({ show: 'others', overall: true })).toBe('/?show=others&overall=1')
    expect(homeHref({ show: 'team', person: 'ana' })).toBe('/?person=ana')
    expect(kindHref('coding', 'team')).toBe('/kinds/coding')
    expect(kindHref('coding', 'others')).toBe('/kinds/coding?show=others')
  })
})

describe('Filters SHOW', () => {
  it('is a radiogroup of three chips with the current group checked', () => {
    render(<Filters filters={homeFilters()} people={people} />)

    const group = screen.getByRole('radiogroup', { name: 'Show' })
    expect(within(group).getAllByRole('radio').map((radio) => radio.getAttribute('value'))).toEqual(['team', 'others', 'subscribers'])
    expect(screen.getByRole('radio', { name: 'Every team' })).toBeChecked()
    expect(screen.getByRole('radio', { name: 'Everyone else' })).not.toBeChecked()
  })

  it('offers Every subscribers as a disabled stub that says it is coming soon', async () => {
    render(<Filters filters={homeFilters()} people={people} />)

    const stub = screen.getByRole('radio', { name: /Every subscribers/ })
    expect(stub).toHaveAttribute('aria-disabled', 'true')
    expect(stub).toBeDisabled()
    expect(screen.getByText('Coming soon')).toBeInTheDocument()
    await userEvent.click(stub)
    expect(get).not.toHaveBeenCalled()
  })

  it('does not put counts on the chips', () => {
    render(<Filters filters={homeFilters()} people={people} />)

    expect(within(screen.getByRole('radiogroup', { name: 'Show' })).queryByText(/\d/)).not.toBeInTheDocument()
  })

  it('visits Home with the new group and drops the selected person, who belongs to one group', () => {
    render(<Filters filters={homeFilters({ person: 'ana' })} people={people} />)

    fireEvent.click(screen.getByRole('radio', { name: 'Everyone else' }))

    expect(get).toHaveBeenCalledWith('/', { show: 'others' }, { preserveScroll: true, preserveState: true })
  })

  it('keeps the Overall view when the group changes', () => {
    render(<Filters filters={homeFilters({ overall: true })} people={people} />)

    fireEvent.click(screen.getByRole('radio', { name: 'Everyone else' }))

    expect(get).toHaveBeenCalledWith('/', { show: 'others', overall: '1' }, expect.any(Object))
  })
})

describe('Filters PERSON', () => {
  it('is a labelled select with All of us first, then the people in the group', () => {
    render(<Filters filters={homeFilters()} people={people} />)

    const select = screen.getByLabelText('Person')
    expect(within(select).getAllByRole('option').map((option) => option.textContent)).toEqual(['All of us', 'Ana Every', 'Dee Every'])
    expect(select).toHaveValue('')
  })

  it('shows the selected person and visits Home with the handle, keeping the group', () => {
    render(<Filters filters={homeFilters({ show: 'others', person: 'dee' })} people={people} />)

    const select = screen.getByLabelText('Person')
    expect(select).toHaveValue('dee')

    fireEvent.change(select, { target: { value: 'ana' } })
    expect(get).toHaveBeenCalledWith('/', { show: 'others', person: 'ana' }, { preserveScroll: true, preserveState: true })

    fireEvent.change(select, { target: { value: '' } })
    expect(get).toHaveBeenLastCalledWith('/', { show: 'others' }, expect.any(Object))
  })
})

describe('ViewToggle', () => {
  it('links the two views and marks the current one', () => {
    render(<ViewToggle filters={homeFilters()} />)

    expect(screen.getByRole('link', { name: 'By kind of work' })).toHaveAttribute('aria-current', 'page')
    expect(screen.getByRole('link', { name: 'By kind of work' })).toHaveAttribute('href', '/')
    expect(screen.getByRole('link', { name: 'Overall top 10' })).toHaveAttribute('href', '/?overall=1')
    expect(screen.getByRole('link', { name: 'Overall top 10' })).not.toHaveAttribute('aria-current')
  })

  it('marks Overall when it is showing and keeps the group in both links', () => {
    render(<ViewToggle filters={homeFilters({ show: 'others', overall: true })} />)

    expect(screen.getByRole('link', { name: 'Overall top 10' })).toHaveAttribute('aria-current', 'page')
    expect(screen.getByRole('link', { name: 'By kind of work' })).toHaveAttribute('href', '/?show=others')
    expect(screen.getByRole('link', { name: 'Overall top 10' })).toHaveAttribute('href', '/?show=others&overall=1')
  })
})
