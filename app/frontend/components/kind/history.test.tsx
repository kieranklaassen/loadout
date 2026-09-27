import { render, screen, within } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import { eras } from '../../test/kind_fixtures'
import History from './history'

describe('History', () => {
  it('lists the eras oldest first with their start dates, tools and models', () => {
    render(<History eras={eras} />)

    const items = screen.getAllByRole('listitem')
    expect(items).toHaveLength(3)
    expect(items[0]).toHaveTextContent('Feb 3, 2025')
    expect(items[0]).toHaveTextContent('Cursor')
    expect(items[0]).toHaveTextContent('GPT-6 Astra')
    expect(items[2]).toHaveTextContent('Mar 2, 2026')
    expect(items[2]).toHaveTextContent('Claude Opus 5.5')
    expect(within(items[0]).getByText('Feb 3, 2025')).toHaveAttribute('datetime', '2025-02-03')
  })

  it('marks the era that runs to today as Now, in yellow', () => {
    render(<History eras={eras} />)

    const items = screen.getAllByRole('listitem')
    expect(within(items[2]).getByText('Now')).toBeInTheDocument()
    expect(items[2].querySelector('.panel')).toHaveClass('border-yellow')
    expect(within(items[0]).queryByText('Now')).not.toBeInTheDocument()
    expect(items[0].querySelector('.panel')).not.toHaveClass('border-yellow')
  })

  it('marks no era Now when the last one has ended', () => {
    render(<History eras={eras.map((era, index) => (index === 2 ? { ...era, to: '2026-09-01' } : era))} />)

    expect(screen.queryByText('Now')).not.toBeInTheDocument()
    expect(document.querySelector('.border-yellow')).toBeNull()
  })

  it('says so when nobody counted had a model', () => {
    render(<History eras={eras} />)

    expect(within(screen.getAllByRole('listitem')[1]).getByText('No model picked')).toBeInTheDocument()
  })
})
