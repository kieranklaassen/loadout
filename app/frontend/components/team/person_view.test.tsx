import { render, screen, within } from '@testing-library/react'
import type { ReactNode } from 'react'
import { describe, expect, it, vi } from 'vitest'
import { personData } from '../../test/home_fixtures'
import { NewInLoadout, PersonTable } from './person_view'

vi.mock('@inertiajs/react', () => ({
  Link: ({ href, children, ...rest }: { href: string; children: ReactNode }) => (
    <a href={href} {...rest}>
      {children}
    </a>
  ),
}))

const rowOf = (name: string) => screen.getByRole('link', { name }).closest('tr') as HTMLElement

describe('PersonTable', () => {
  it('names the columns after the person', () => {
    render(<PersonTable data={personData()} show="team" />)

    expect(screen.getByRole('columnheader', { name: "Dan's tools (the app)" })).toBeInTheDocument()
    expect(screen.getByRole('columnheader', { name: "Dan's models (the AI behind it)" })).toBeInTheDocument()
  })

  it('lists ranked tools and models line by line, with context and effort as chips', () => {
    render(<PersonTable data={personData()} show="team" />)

    const [tools, models] = within(rowOf('Coding')).getAllByRole('cell')
    expect(tools).toHaveTextContent('1st')
    expect(tools).toHaveTextContent('Claude Code')
    expect(tools).toHaveTextContent('2nd')
    expect(tools).toHaveTextContent('Cursor')
    expect(models).toHaveTextContent('Claude Opus 5.5')
    expect(within(models).getByText('1M context')).toBeInTheDocument()
    expect(within(models).getByText('high effort')).toBeInTheDocument()
    expect(within(models).getByText('No model picked')).toBeInTheDocument()
  })

  it('shows the team note only on the first pick and only where the person differs', () => {
    render(<PersonTable data={personData()} show="team" />)

    const [tools, models] = within(rowOf('Coding')).getAllByRole('cell')
    expect(within(tools).getAllByText(/Team's most used/)).toHaveLength(1)
    expect(within(tools).getByText("Team's most used: Claude")).toBeInTheDocument()
    expect(within(models).queryByText(/Team's most used/)).not.toBeInTheDocument()
    expect(within(rowOf('Writing')).queryByText(/Team's most used/)).not.toBeInTheDocument()
  })

  it('says a kind is not ranked yet instead of leaving an empty row', () => {
    render(<PersonTable data={personData()} show="team" />)

    expect(within(rowOf('Music')).getByText('Not ranked yet')).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Music' })).toHaveAttribute('href', '/kinds/music')
  })

  it('marks an item only the owner can see as pending review', () => {
    const data = personData()
    data.kinds[0].picks[1] = { ...data.kinds[0].picks[1], tool: { ...data.kinds[0].picks[1].tool, pending: true } }
    render(<PersonTable data={data} show="team" />)

    expect(within(rowOf('Coding')).getAllByText('Pending review')).toHaveLength(1)
  })
})

describe('NewInLoadout', () => {
  it('names the launched model, where it sits in the loadout and the Vibe Check', () => {
    render(<NewInLoadout data={personData()} />)

    expect(screen.getByText("New in Dan's loadout")).toBeInTheDocument()
    expect(screen.getByText('Claude Opus 5.5')).toBeInTheDocument()
    expect(screen.getByText('1st pick for Coding, in Claude Code. Out Sep 22.')).toBeInTheDocument()
    const link = screen.getByRole('link', { name: 'Vibe Check for Claude Opus 5.5' })
    expect(link).toHaveAttribute('rel', 'noopener noreferrer')
  })

  it('renders nothing when no launched model is in the loadout', () => {
    const { container } = render(<NewInLoadout data={personData({ new_in_loadout: [] })} />)

    expect(container).toBeEmptyDOMElement()
  })
})
