import { render, screen, within } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import { claudeCodeMark, cursorMark, markItem, opusMark, rankedPick } from '../../test/picker_fixtures'
import { profileProps, yourPicks } from '../../test/profile_fixtures'
import LoadoutTable from './loadout_table'

const kinds = profileProps().kinds.filter((kind) => kind.picks.length > 0)

const rowOf = (name: string) => screen.getByRole('rowheader', { name }).closest('tr') as HTMLElement

describe('LoadoutTable', () => {
  it('has a row per ranked kind with the tool and the model as columns', () => {
    render(<LoadoutTable kinds={kinds} you={null} />)

    expect(screen.getAllByRole('columnheader').map((header) => header.textContent)).toEqual(['Kind of work', 'Tool', 'Model'])
    expect(screen.getAllByRole('rowheader').map((header) => header.textContent)).toEqual(['Coding', 'Writing'])
  })

  it('shows the first pick large, later picks as a "then" line, and context and effort as chips', () => {
    render(<LoadoutTable kinds={kinds} you={null} />)

    const [tool, model] = within(rowOf('Coding')).getAllByRole('cell')
    expect(tool).toHaveTextContent('Claude Code')
    expect(tool).toHaveTextContent('then Cursor')
    expect(tool).not.toHaveTextContent(/1st|2nd/)
    expect(model).toHaveTextContent('Claude Opus 5.5')
    expect(within(model).getByText('1M context')).toBeInTheDocument()
    expect(within(model).getByText('high effort')).toBeInTheDocument()
  })

  it('has no "then" line for a single pick and says so when the first pick has no model', () => {
    render(<LoadoutTable kinds={kinds} you={null} />)

    const [tool, model] = within(rowOf('Writing')).getAllByRole('cell')
    expect(tool).not.toHaveTextContent('then')
    expect(model).toHaveTextContent('No model picked')
  })

  it('lists several later picks with commas', () => {
    const picks = [rankedPick({ rank: 1 }), rankedPick({ rank: 2, tool: cursorMark }), rankedPick({ rank: 3, tool: markItem('zed', 'Zed') })]
    render(<LoadoutTable kinds={[{ ...kinds[0], picks }]} you={null} />)

    expect(within(rowOf('Coding')).getByText('then Cursor, Zed')).toBeInTheDocument()
  })

  it('marks an item only its owner can see as pending review', () => {
    const picks = [rankedPick({ tool: { ...claudeCodeMark, pending: true }, model: { ...opusMark, pending: true } })]
    render(<LoadoutTable kinds={[{ ...kinds[0], picks }]} you={null} />)

    expect(within(rowOf('Coding')).getAllByText('Pending review')).toHaveLength(2)
  })
})

describe('LoadoutTable comparing', () => {
  it('adds a You column after Model with the viewer\'s first tool and model in the same format', () => {
    render(<LoadoutTable kinds={kinds} you={yourPicks} />)

    expect(screen.getAllByRole('columnheader').map((header) => header.textContent)).toEqual(['Kind of work', 'Tool', 'Model', 'You'])
    const you = within(rowOf('Coding')).getAllByRole('cell')[2]
    expect(you).toHaveTextContent('Cursor')
    expect(you).toHaveTextContent('GPT-6 Astra')
    expect(you).not.toHaveTextContent('Claude Code')
  })

  it('says "Not ranked" where the viewer ranked nothing, and adds no row for a kind only the viewer ranked', () => {
    render(<LoadoutTable kinds={kinds} you={yourPicks} />)

    expect(within(rowOf('Writing')).getAllByRole('cell')[2]).toHaveTextContent('Not ranked')
    expect(screen.queryByRole('rowheader', { name: 'Video' })).not.toBeInTheDocument()
    expect(screen.getAllByRole('rowheader')).toHaveLength(2)
  })

  it('puts the viewer\'s value on a second line in the tool and model cells for a phone', () => {
    render(<LoadoutTable kinds={kinds} you={yourPicks} />)

    const [tool, model] = within(rowOf('Coding')).getAllByRole('cell')
    expect(tool).toHaveTextContent('You: Cursor')
    expect(model).toHaveTextContent('You: GPT-6 Astra')
    const [writingTool, writingModel] = within(rowOf('Writing')).getAllByRole('cell')
    expect(writingTool).toHaveTextContent('You: Not ranked')
    expect(writingModel).not.toHaveTextContent('You:')
  })

  it('says the viewer picked no model when they ranked a tool alone', () => {
    const you = { coding: [rankedPick({ rank: 1, tool: cursorMark, model: null })] }
    render(<LoadoutTable kinds={kinds} you={you} />)

    const [, model, column] = within(rowOf('Coding')).getAllByRole('cell')
    expect(model).toHaveTextContent('You: No model picked')
    expect(column).toHaveTextContent('No model picked')
  })

  it('shows nothing of the viewer without a comparison', () => {
    render(<LoadoutTable kinds={kinds} you={null} />)

    expect(screen.queryByText(/You/)).not.toBeInTheDocument()
    expect(screen.queryByText('Not ranked')).not.toBeInTheDocument()
  })
})
