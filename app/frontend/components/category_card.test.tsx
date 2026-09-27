import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it, vi } from 'vitest'
import { catalog, coding, cursor, gpt, runway } from '../test/picker_fixtures'
import CategoryCard from './category_card'

describe('CategoryCard', () => {
  it('numbers the category and shows its blurb', () => {
    render(<CategoryCard category={coding} index={0} catalog={catalog} picks={[]} onChange={vi.fn()} />)

    expect(screen.getByRole('heading', { name: 'Coding' })).toBeInTheDocument()
    expect(screen.getByText('01')).toBeInTheDocument()
    expect(screen.getByText(/shipping code/)).toBeInTheDocument()
  })

  it('shows a picked tool from outside the suggestions as a selected tile', () => {
    render(<CategoryCard category={coding} index={0} catalog={catalog} picks={[{ tool: runway, model: null, primary: true, note: null }]} onChange={vi.fn()} />)

    expect(screen.getByRole('button', { name: /runway/i, pressed: true })).toBeInTheDocument()
    expect(screen.getByText('Go-to')).toBeInTheDocument()
  })

  it('keeps a picked model visible as a chip even when it is not suggested', () => {
    const category = { ...coding, model_slugs: [] }
    render(<CategoryCard category={category} index={0} catalog={catalog} picks={[{ tool: cursor, model: gpt, primary: true, note: null }]} onChange={vi.fn()} />)

    expect(screen.getByRole('button', { name: 'GPT-6 Astra', pressed: true })).toBeInTheDocument()
  })

  it('searches models beyond the chips', async () => {
    const onChange = vi.fn()
    const category = { ...coding, model_slugs: [] }
    render(<CategoryCard category={category} index={0} catalog={catalog} picks={[{ tool: cursor, model: null, primary: true, note: null }]} onChange={onChange} />)

    await userEvent.click(screen.getByRole('button', { name: /add a model/i }))
    await userEvent.type(screen.getByRole('combobox', { name: /search models for cursor/i }), 'gpt{Enter}')

    expect(onChange).toHaveBeenCalledWith([expect.objectContaining({ model: expect.objectContaining({ slug: 'gpt-6-astra' }) })])
  })
})
