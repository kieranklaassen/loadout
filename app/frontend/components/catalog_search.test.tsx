import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it, vi } from 'vitest'
import { catalog } from '../test/picker_fixtures'
import CatalogSearch from './catalog_search'

describe('CatalogSearch', () => {
  it('lists matches and picks one with the keyboard', async () => {
    const onSelect = vi.fn()
    render(<CatalogSearch items={catalog.tools} onSelect={onSelect} label="Search tools" placeholder="Search" />)

    await userEvent.type(screen.getByRole('combobox', { name: 'Search tools' }), 'clau')
    expect(screen.getAllByRole('option').map((option) => option.textContent)).toEqual(
      expect.arrayContaining([expect.stringContaining('Claude Code'), expect.stringContaining('Add “clau”')]),
    )

    await userEvent.keyboard('{Enter}')
    expect(onSelect).toHaveBeenCalledWith(expect.objectContaining({ slug: 'claude-code' }))
    expect(screen.getByRole('combobox')).toHaveValue('')
  })

  it('offers to add a name the catalog does not know', async () => {
    const onSelect = vi.fn()
    render(<CatalogSearch items={catalog.tools} onSelect={onSelect} label="Search tools" placeholder="Search" />)

    await userEvent.type(screen.getByRole('combobox'), 'Hedra')
    await userEvent.click(screen.getByRole('option', { name: /add “hedra”/i }))

    expect(onSelect).toHaveBeenCalledWith(expect.objectContaining({ slug: '', name: 'Hedra', pending: true }))
  })

  it('hides excluded items', async () => {
    render(<CatalogSearch items={catalog.tools} exclude={['cursor']} onSelect={vi.fn()} label="Search tools" placeholder="Search" />)

    await userEvent.type(screen.getByRole('combobox'), 'cursor')

    expect(screen.queryAllByRole('option')).toHaveLength(0)
  })
})
