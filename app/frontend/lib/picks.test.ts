import { describe, expect, it } from 'vitest'
import { claudeCode, cursor, gpt, opus, runway } from '../test/picker_fixtures'
import {
  changedCategories,
  countPicks,
  draftItem,
  makePrimary,
  removePick,
  searchItems,
  setModel,
  setNote,
  toOperations,
  toggleTool,
} from './picks'

describe('picks', () => {
  it('makes the first tapped tool the go-to and toggles tools off', () => {
    let picks = toggleTool([], cursor)
    picks = toggleTool(picks, claudeCode)
    expect(picks.map((pick) => [pick.tool.slug, pick.primary])).toEqual([
      ['cursor', true],
      ['claude-code', false],
    ])

    picks = toggleTool(picks, cursor)
    expect(picks.map((pick) => [pick.tool.slug, pick.primary])).toEqual([['claude-code', true]])
  })

  it('sets, switches, and clears a model', () => {
    let picks = toggleTool([], cursor)
    picks = setModel(picks, 0, opus)
    expect(picks[0]?.model?.slug).toBe('claude-opus-5-5')
    picks = setModel(picks, 0, gpt)
    expect(picks[0]?.model?.slug).toBe('gpt-6-astra')
    picks = setModel(picks, 0, gpt)
    expect(picks[0]?.model).toBeNull()
  })

  it('keeps exactly one go-to', () => {
    let picks = toggleTool(toggleTool([], cursor), claudeCode)
    picks = makePrimary(picks, 1)
    expect(picks.map((pick) => pick.primary)).toEqual([false, true])
    picks = removePick(picks, 1)
    expect(picks.map((pick) => pick.primary)).toEqual([true])
  })

  it('caps notes at 280 characters', () => {
    const picks = setNote(toggleTool([], cursor), 0, 'a'.repeat(300))
    expect(picks[0]?.note).toHaveLength(280)
  })

  it('drafts a pending item for a new name', () => {
    expect(draftItem('  hedra   studio ')).toMatchObject({ slug: '', name: 'hedra studio', monogram: 'Hs', pending: true })
  })

  it('searches by name or maker, prefix matches first', () => {
    const items = [claudeCode, cursor, runway]
    expect(searchItems(items, 'cu').map((item) => item.slug)).toEqual(['cursor'])
    expect(searchItems(items, 'anthropic').map((item) => item.slug)).toEqual(['claude-code'])
    expect(searchItems(items, '  ')).toEqual([])
  })

  it('finds changed categories and builds replace_category operations with names for new items', () => {
    const saved = { coding: toggleTool([], cursor) }
    const current = { coding: setModel(toggleTool([], cursor), 0, opus), video: toggleTool([], draftItem('Hedra')), writing: [] }

    const changed = changedCategories(saved, current, ['coding', 'writing', 'video'])
    expect(changed).toEqual(['coding', 'video'])
    expect(toOperations(current, changed)).toEqual([
      { op: 'replace_category', category: 'coding', picks: [{ tool: 'cursor', model: 'claude-opus-5-5', primary: true, note: null }] },
      { op: 'replace_category', category: 'video', picks: [{ tool: 'Hedra', model: null, primary: true, note: null }] },
    ])
  })

  it('counts picks and categories', () => {
    expect(countPicks({ coding: toggleTool(toggleTool([], cursor), claudeCode), video: [] })).toEqual({ picks: 2, categories: 1 })
  })
})
