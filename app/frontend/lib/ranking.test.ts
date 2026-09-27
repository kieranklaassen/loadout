import { describe, expect, it } from 'vitest'
import { claudeCodeMark, cursorMark, markItem, opusMark, rankedPick, suggestion } from '../test/picker_fixtures'
import {
  layoutSlots,
  modelAction,
  movedMessage,
  optionGroups,
  progress,
  progressLabel,
  startedCount,
  teamCountText,
  toolAction,
  toolsUsedElsewhere,
  type CatalogOption,
  type EditorKind,
  type TeamStanding,
} from './ranking'

const coding = { slug: 'coding', name: 'Coding', blurb: 'Writing and shipping software.' }
const runway = markItem('runway', 'Runway')
const zed = markItem('zed', 'Zed')

const kind = (overrides: Partial<EditorKind> = {}): EditorKind => ({ category: coding, picks: [], suggestions: [], to_confirm: 0, ...overrides })
const standing = (item = cursorMark, n = 2): TeamStanding => ({ item, count: { n, of: 6 }, yours_rank: null })

describe('layoutSlots', () => {
  it('gives each slot its pick and stacks suggestions in the slot they would land in', () => {
    const first = rankedPick({ rank: 1 })
    const second = suggestion({ id: 1, target_rank: 2 })
    const alsoSecond = suggestion({ id: 2, tool: runway, target_rank: 2 })
    const change = suggestion({ id: 3, tool: claudeCodeMark, target_rank: 1 })

    const { slots, unplaced } = layoutSlots(kind({ picks: [first], suggestions: [second, alsoSecond, change] }))

    expect(slots.map((slot) => slot.rank)).toEqual([1, 2, 3])
    expect(slots[0]).toMatchObject({ pick: first, suggestions: [change] })
    expect(slots[1]).toMatchObject({ pick: null, suggestions: [second, alsoSecond] })
    expect(slots[2]).toMatchObject({ pick: null, suggestions: [] })
    expect(unplaced).toEqual([])
  })

  it('keeps a suggestion with no slot apart, for the member to choose what it replaces', () => {
    const noSlot = suggestion({ id: 9, target_rank: null })
    const full = kind({ picks: [1, 2, 3].map((rank) => rankedPick({ rank })), suggestions: [noSlot] })

    const { slots, unplaced } = layoutSlots(full)

    expect(unplaced).toEqual([noSlot])
    expect(slots.flatMap((slot) => slot.suggestions)).toEqual([])
  })
})

describe('progress', () => {
  it('counts picks plus the slots suggestions would fill, and every suggestion to confirm', () => {
    const state = kind({ picks: [rankedPick({ rank: 1 })], suggestions: [suggestion({ id: 1, target_rank: 2 })] })

    expect(progress(state)).toEqual({ filled: 2, toConfirm: 1 })
    expect(progressLabel(state)).toBe('2 of 3 · 1 to confirm')
  })

  it('never passes 3 while to confirm counts them all', () => {
    const picks = [1, 2, 3].map((rank) => rankedPick({ rank }))
    const suggestions = [1, 2, 3].map((id) => suggestion({ id, target_rank: id === 3 ? null : id }))
    const state = kind({ picks, suggestions })

    expect(progress(state)).toEqual({ filled: 3, toConfirm: 3 })
    expect(progressLabel(state)).toBe('3 of 3 · 3 to confirm')
  })

  it('counts suggestions stacked in one empty slot as one slot', () => {
    const state = kind({ suggestions: [suggestion({ id: 1, target_rank: 1 }), suggestion({ id: 2, tool: runway, target_rank: 1 })] })

    expect(progress(state)).toEqual({ filled: 1, toConfirm: 2 })
  })

  it('reads Not started, 1 of 3 and 3 of 3 without a to-confirm tail when nothing waits', () => {
    expect(progressLabel(kind())).toBe('Not started')
    expect(progressLabel(kind({ picks: [rankedPick({ rank: 1 })] }))).toBe('1 of 3')
    expect(progressLabel(kind({ picks: [1, 2, 3].map((rank) => rankedPick({ rank })) }))).toBe('3 of 3')
  })

  it('counts a kind as started when a pick or a suggestion holds a slot', () => {
    const started = kind({ picks: [rankedPick()] })
    const waiting = kind({ suggestions: [suggestion({ target_rank: 1 })] })

    expect(startedCount([kind(), started, waiting])).toBe(2)
  })
})

describe('the team list rules', () => {
  const two = kind({ picks: [rankedPick({ rank: 1, model: opusMark }), rankedPick({ rank: 2, tool: cursorMark, model: null })] })

  it('offers a tool the first empty slot and says which', () => {
    expect(toolAction(two, standing(runway))).toEqual({ type: 'use', label: 'Use as 3rd pick', rank: 3 })
    expect(toolAction(kind(), standing(runway))).toEqual({ type: 'use', label: 'Use as 1st pick', rank: 1 })
  })

  it('says where the member already has a tool', () => {
    expect(toolAction(two, standing(claudeCodeMark))).toEqual({ type: 'have', text: 'You have it 1st' })
    expect(toolAction(two, standing(cursorMark))).toEqual({ type: 'have', text: 'You have it 2nd' })
  })

  it('offers nothing on a full kind, except telling what the member has', () => {
    const full = kind({ picks: [1, 2, 3].map((rank) => rankedPick({ rank, tool: markItem(`tool-${rank}`, `Tool ${rank}`), model: null })) })

    expect(toolAction(full, standing(runway))).toBeNull()
    expect(modelAction(full, standing(opusMark))).toBeNull()
    expect(toolAction(full, standing(full.picks[1]!.tool))).toEqual({ type: 'have', text: 'You have it 2nd' })
  })

  it('offers a model the first pick that has a tool and no model', () => {
    const gpt = markItem('gpt-6-astra', 'GPT-6 Astra', 'model')

    expect(modelAction(two, standing(gpt))).toEqual({ type: 'use', label: 'Use in 2nd pick', rank: 2 })
  })

  it('offers a model nothing when every pick has one or nothing is picked yet', () => {
    const gpt = markItem('gpt-6-astra', 'GPT-6 Astra', 'model')
    const allModels = kind({ picks: [rankedPick({ rank: 1, model: opusMark })] })

    expect(modelAction(allModels, standing(gpt))).toBeNull()
    expect(modelAction(kind(), standing(gpt))).toBeNull()
  })

  it('says when the member already uses a model', () => {
    expect(modelAction(two, standing(opusMark))).toEqual({ type: 'have', text: 'You use it' })
  })

  it('writes the count as N of M, with the verb agreeing, and marks a launch', () => {
    expect(teamCountText(standing(cursorMark, 5))).toBe('5 of 6 use it')
    expect(teamCountText(standing(cursorMark, 1))).toBe('1 of 6 uses it')
    expect(teamCountText(standing(opusMark, 2), true)).toBe('New · 2 of 6 are trying it')
    expect(teamCountText(standing(opusMark, 1), true)).toBe('New · 1 of 6 is trying it')
  })
})

describe('optionGroups', () => {
  const option = (item: typeof cursorMark, suggested_for: string[]): CatalogOption => ({ ...item, suggested_for })

  it('lists the items that suit the kind first and the rest after, each once', () => {
    const options = [option(runway, ['video']), option(cursorMark, ['coding']), option(zed, [])]

    const { suggested, rest } = optionGroups(options, 'coding', null)

    expect(suggested.map((item) => item.slug)).toEqual(['cursor'])
    expect(rest.map((item) => item.slug)).toEqual(['runway', 'zed'])
  })

  it('keeps a saved item the catalog no longer lists', () => {
    const { rest } = optionGroups([option(cursorMark, ['coding'])], 'coding', zed)

    expect(rest.map((item) => item.slug)).toEqual(['zed'])
  })
})

describe('slot helpers', () => {
  it('finds the tools other slots use', () => {
    const state = kind({ picks: [rankedPick({ rank: 1 }), rankedPick({ rank: 2, tool: cursorMark })] })

    expect([...toolsUsedElsewhere(state, 1)]).toEqual(['cursor'])
    expect([...toolsUsedElsewhere(state, 3)].sort()).toEqual(['claude-code', 'cursor'])
  })

  it('announces a move as the new rank, spelled as an ordinal', () => {
    expect(movedMessage('Cursor', 1)).toBe('Cursor is now 1st')
  })
})
