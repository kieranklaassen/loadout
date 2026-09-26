import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { useState } from 'react'
import { describe, expect, it } from 'vitest'
import { catalog, coding, cursor, opus, video } from '../test/picker_fixtures'
import type { PicksByCategory } from '../types'
import type { PickerMode } from './category_card'
import ToolPicker from './tool_picker'

let latest: PicksByCategory = {}

function Harness({ initial = {}, mode = 'quick' }: { initial?: PicksByCategory; mode?: PickerMode }) {
  const [value, setValue] = useState<PicksByCategory>(initial)
  latest = value
  return (
    <ToolPicker
      categories={[coding, video]}
      catalog={catalog}
      value={value}
      mode={mode}
      onChange={(next) => {
        latest = next
        setValue(next)
      }}
    />
  )
}

const card = (name: string) => screen.getByRole('region', { name })

describe('ToolPicker', () => {
  it('shows each category with its suggested tools', () => {
    render(<Harness />)

    expect(within(card('Coding')).getAllByRole('button', { pressed: false }).map((b) => b.textContent)).toEqual(['CuCursor', 'ClClaude Code'])
    expect(within(card('Video')).getByRole('button', { name: /runway/i })).toBeInTheDocument()
  })

  it('taps a tool, picks a model chip, and moves the go-to', async () => {
    render(<Harness />)
    const coding = card('Coding')

    await userEvent.click(within(coding).getByRole('button', { name: 'Cursor' }))
    await userEvent.click(within(coding).getByRole('button', { name: /claude code/i, pressed: false }))
    expect(within(coding).getByText('2 picked')).toBeInTheDocument()

    const cursorModels = within(coding).getByRole('group', { name: 'Model for Cursor' })
    await userEvent.click(within(cursorModels).getByRole('button', { name: 'Claude Opus 5.5' }))
    await userEvent.click(within(coding).getByRole('button', { name: /make go-to/i }))

    expect(latest.coding?.map((pick) => [pick.tool.slug, pick.model?.slug ?? null, pick.primary])).toEqual([
      ['cursor', 'claude-opus-5-5', false],
      ['claude-code', null, true],
    ])
    expect(latest.video).toBeUndefined()
  })

  it('adds a new tool by name as a pending pick', async () => {
    render(<Harness />)
    const videoCard = card('Video')

    await userEvent.type(within(videoCard).getByRole('combobox'), 'Hedra{Enter}')

    expect(latest.video?.[0]).toMatchObject({ tool: { name: 'Hedra', slug: '', pending: true }, primary: true })
    expect(within(videoCard).getByText(/new to the catalog/i)).toBeInTheDocument()
  })

  it('lets the full editor write a note and remove a pick', async () => {
    render(<Harness mode="full" initial={{ coding: [{ tool: cursor, model: opus, primary: true, note: null }] }} />)
    const coding = card('Coding')

    await userEvent.type(within(coding).getByRole('textbox', { name: /why cursor/i }), 'Fast.')
    expect(latest.coding?.[0]?.note).toBe('Fast.')

    await userEvent.click(within(coding).getByRole('button', { name: 'Remove Cursor' }))
    expect(latest.coding).toEqual([])
  })

  it('keeps notes and remove out of the quick onboarding picker', () => {
    render(<Harness initial={{ coding: [{ tool: cursor, model: null, primary: true, note: null }] }} />)

    expect(screen.queryByRole('textbox', { name: /why cursor/i })).not.toBeInTheDocument()
    expect(screen.queryByRole('button', { name: 'Remove Cursor' })).not.toBeInTheDocument()
  })
})
