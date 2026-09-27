import { render, screen, within } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import { claudeCodeMark, cursorMark, opusMark } from '../../test/picker_fixtures'
import OverallTopTen from './overall_top_ten'

describe('OverallTopTen', () => {
  const overall = {
    tools: [
      { item: claudeCodeMark, count: { n: 5, of: 6 } },
      { item: cursorMark, count: { n: 3, of: 6 } },
    ],
    models: [{ item: opusMark, count: { n: 4, of: 6 } }],
  }

  it('lists tools and models separately, each row with its rank and N of M', () => {
    render(<OverallTopTen overall={overall} />)

    const tools = screen.getByRole('region', { name: 'Tools' })
    const rows = within(tools).getAllByRole('listitem')
    expect(rows).toHaveLength(2)
    expect(rows[0]).toHaveTextContent('1')
    expect(rows[0]).toHaveTextContent('Claude Code')
    expect(within(rows[0]).getByText('5 of 6 use it')).toBeInTheDocument()
    expect(rows[1]).toHaveTextContent('2')
    expect(within(rows[1]).getByText('3 of 6 use it')).toBeInTheDocument()

    const models = screen.getByRole('region', { name: 'Models' })
    expect(within(models).getByText('Claude Opus 5.5')).toBeInTheDocument()
    expect(within(models).getByText('4 of 6 use it')).toBeInTheDocument()
  })

  it('marks only the first place in yellow', () => {
    render(<OverallTopTen overall={overall} />)

    const [first, second] = within(screen.getByRole('region', { name: 'Tools' })).getAllByRole('listitem')
    expect(within(first).getByText('1')).toHaveClass('text-yellow')
    expect(within(second).getByText('2')).not.toHaveClass('text-yellow')
  })
})
