import { render, screen, within } from '@testing-library/react'
import type { ReactNode } from 'react'
import { describe, expect, it, vi } from 'vitest'
import { claudeCodeMark } from '../../test/picker_fixtures'
import { codingRow, musicKind, writingKind } from '../../test/home_fixtures'
import WhatWeUseTable from './what_we_use_table'

vi.mock('@inertiajs/react', () => ({
  Link: ({ href, children, ...rest }: { href: string; children: ReactNode }) => (
    <a href={href} {...rest}>
      {children}
    </a>
  ),
}))

const NOW = new Date('2026-09-26T12:00:00Z')
const weeksAgo = (weeks: number) => new Date(NOW.getTime() - weeks * 7 * 86_400_000).toISOString()

describe('WhatWeUseTable', () => {
  it('names the columns for the tool (the app) and the model (the AI behind it)', () => {
    render(<WhatWeUseTable rows={[codingRow()]} show="team" />)

    expect(screen.getByRole('columnheader', { name: 'Kind of work' })).toBeInTheDocument()
    expect(screen.getByRole('columnheader', { name: 'Most used tool (the app)' })).toBeInTheDocument()
    expect(screen.getByRole('columnheader', { name: 'Most used model (the AI behind it)' })).toBeInTheDocument()
  })

  it('shows the leader with N of M and one runner-up in each cell', () => {
    render(<WhatWeUseTable rows={[codingRow()]} show="team" />)

    const row = screen.getByRole('row', { name: /Coding/ })
    const [tool, model] = within(row).getAllByRole('cell')
    expect(within(row).getByRole('link', { name: 'Coding' })).toHaveAttribute('href', '/kinds/coding')
    expect(tool).toHaveTextContent('Claude Code')
    expect(within(tool).getByText('5 of 6 use it')).toBeInTheDocument()
    expect(within(tool).getByText('Cursor')).toBeInTheDocument()
    expect(within(tool).getByText('2 of 6 use it')).toHaveClass('sr-only')
    expect(model).toHaveTextContent('Claude Opus 5.5')
    expect(within(model).getByText('4 of 6 use it')).toBeInTheDocument()
    expect(within(model).getByText('GPT-6 Astra')).toBeInTheDocument()
  })

  it('leaves out the runner-up when there is none', () => {
    const row = codingRow({ top_tool: { item: claudeCodeMark, count: { n: 1, of: 1 }, runner_up: null } })
    render(<WhatWeUseTable rows={[row]} show="team" />)

    expect(screen.queryByText('Cursor')).not.toBeInTheDocument()
  })

  it('keeps a kind nobody ranked in place, without a zero-of-zero count', () => {
    const unranked = { category: writingKind, top_tool: null, top_model: null, ranked: { n: 0, of: 6 }, last_update_at: null, stale: false }
    render(<WhatWeUseTable rows={[codingRow(), unranked]} show="team" />)

    expect(screen.getByRole('link', { name: 'Writing' })).toBeInTheDocument()
    expect(screen.getByText('Nobody has ranked this yet')).toBeInTheDocument()
    expect(screen.queryByText(/0 of/)).not.toBeInTheDocument()
  })

  it('says so when the tool has no model behind it', () => {
    const tools = codingRow({ category: musicKind, top_model: null })
    render(<WhatWeUseTable rows={[tools]} show="team" />)

    expect(screen.getByText('No model picked')).toBeInTheDocument()
  })

  it('shows staleness in coral from the server flag, in weeks then months', () => {
    const rows = [
      codingRow({ stale: true, last_update_at: weeksAgo(7) }),
      codingRow({ category: writingKind, stale: true, last_update_at: weeksAgo(13) }),
      codingRow({ category: musicKind, stale: false, last_update_at: weeksAgo(2) }),
    ]
    render(<WhatWeUseTable rows={rows} show="team" now={NOW} />)

    expect(screen.getByText('Not updated in 7 weeks')).toHaveClass('text-coral')
    expect(screen.getByText('Not updated in 3 months')).toHaveClass('text-coral')
    expect(screen.getAllByText(/Not updated/)).toHaveLength(2)
  })

  it('carries the group being shown to the kind page so its counts match', () => {
    render(<WhatWeUseTable rows={[codingRow()]} show="others" />)

    expect(screen.getByRole('link', { name: 'Coding' })).toHaveAttribute('href', '/kinds/coding?show=others')
  })

  it('labels each cell for the stacked phone layout', () => {
    render(<WhatWeUseTable rows={[codingRow()]} show="team" />)

    const [tool, model] = within(screen.getByRole('row', { name: /Coding/ })).getAllByRole('cell')
    expect(tool).toHaveAttribute('data-label', 'Most used tool')
    expect(model).toHaveAttribute('data-label', 'Most used model')
    expect(screen.getByRole('table')).toHaveClass('stack-table')
  })
})
