import { describe, expect, it } from 'vitest'
import { markItem, rankedPick } from '../test/picker_fixtures'
import { assemble, canAdd, matchScore, modelForTool, modelSections, toolSections } from './picker'
import type { CatalogOption, EditorKind } from './ranking'

const video = { slug: 'video', name: 'Video', blurb: 'Generating and editing video.' }
const model = (slug: string, name: string, suggested_for: string[] = [], maker: string | null = null): CatalogOption => ({ ...markItem(slug, name, 'model'), suggested_for, maker })
const tool = (slug: string, name: string, models: string[] = [], suggested_for: string[] = ['video']): CatalogOption => ({ ...markItem(slug, name), suggested_for, models })

const veo31 = model('veo-4', 'Veo 3.1', ['video'], 'Google')
const veo3 = model('veo-3', 'Veo 3', ['video'], 'Google')
const omni = model('gemini-omni-flash', 'Gemini Omni Flash', ['video'], 'Google')
const kling = model('kling-3', 'Kling 3', ['video', 'animation'], 'Kuaishou')
const opus = model('claude-opus-5-5', 'Claude Opus 5.5', ['coding'], 'Anthropic')
const nano = model('nano-banana-2', 'Nano Banana 2', ['image'], 'Google')
const models = [opus, veo31, veo3, omni, kling, nano]
const slugs = (options: { slug: string }[]) => options.map((option) => option.slug)
const labels = (sections: ReturnType<typeof modelSections>) => sections.filter((section) => section.options.length > 0).map((section) => [section.label, slugs(section.options), section.always])

describe('modelSections', () => {
  it('lists the models the tool runs first, then the other models for the kind, and hides the rest', () => {
    const veo = tool('veo', 'Veo', ['veo-4', 'veo-3'])

    expect(labels(modelSections({ models, tool: veo, category: video, saved: null }))).toEqual([
      ['Works with Veo', ['veo-4', 'veo-3'], true],
      ['Other models for Video', ['gemini-omni-flash', 'kling-3'], true],
      ['All models', ['claude-opus-5-5', 'nano-banana-2'], false],
    ])
  })

  it('keeps only the tool’s models that suit the kind when some do, and all of them when none do', () => {
    const gemini = tool('gemini', 'Gemini', ['nano-banana-2', 'veo-4', 'veo-3', 'gemini-omni-flash'])
    expect(labels(modelSections({ models, tool: gemini, category: video, saved: null }))[0]).toEqual(['Works with Gemini', ['veo-4', 'veo-3', 'gemini-omni-flash'], true])

    const image = { slug: 'image', name: 'Image', blurb: '' }
    const veo = tool('veo', 'Veo', ['veo-4', 'veo-3'])
    expect(labels(modelSections({ models, tool: veo, category: image, saved: null }))[0]).toEqual(['Works with Veo', ['veo-4', 'veo-3'], true])
  })

  it('falls back to Suggested for the kind when the tool pairs with nothing', () => {
    const pika = tool('pika', 'Pika')

    expect(labels(modelSections({ models, tool: pika, category: video, saved: null }))).toEqual([
      ['Suggested for Video', ['veo-4', 'veo-3', 'gemini-omni-flash', 'kling-3'], true],
      ['All models', ['claude-opus-5-5', 'nano-banana-2'], false],
    ])
  })

  it('lists the member’s pending models on their own, and keeps a saved model the catalog no longer offers', () => {
    const mine = { ...model('my-model-x1y2', 'My Model'), pending: true }
    const gone = markItem('sora-2', 'Sora 2', 'model')
    const sections = modelSections({ models: [...models, mine], tool: null, category: video, saved: gone })

    expect(sections.find((section) => section.id === 'yours')?.options.map((option) => option.slug)).toEqual(['my-model-x1y2'])
    expect(sections.find((section) => section.id === 'all')?.options.map((option) => option.slug)).toContain('sora-2')
  })

  it('orders the kind’s models by how many on the team use them, with the count as a note', () => {
    const standings = [{ item: kling, count: { n: 3, of: 6 }, yours_rank: null, launched: false }]
    const kind = modelSections({ models, tool: null, category: video, saved: null, standings })[0]!

    expect(slugs(kind.options)).toEqual(['kling-3', 'veo-4', 'veo-3', 'gemini-omni-flash'])
    expect(kind.options[0]!.note).toBe('3 of 6 use it')
  })
})

describe('toolSections', () => {
  it('disables a tool another slot holds, saying where it is', () => {
    const kind: EditorKind = { category: video, picks: [rankedPick({ rank: 1, tool: markItem('veo', 'Veo') })], suggestions: [], to_confirm: 0 }
    const sections = toolSections({ tools: [tool('veo', 'Veo'), tool('kling', 'Kling')], kind, rank: 2, saved: null })

    expect(sections[0]!.options).toMatchObject([{ slug: 'veo', disabled: true, note: 'Your 1st pick' }, { slug: 'kling' }])
    expect(sections[0]!.options[1]!.disabled).toBeUndefined()
  })
})

describe('matchScore', () => {
  it('ranks an exact name over a prefix over a word over a substring over a maker, and matches loosely last', () => {
    const score = (query: string, option = veo31) => matchScore(query, option)?.score ?? null

    expect(score('veo 3.1')).toBeGreaterThan(score('veo')!)
    expect(score('veo')).toBeGreaterThan(score('3.1')!)
    expect(score('3.1')).toBeGreaterThan(score('google')!)
    expect(score('google')).toBeGreaterThan(score('vo31')!)
    expect(matchScore('vo31', veo31)?.strong).toBe(false)
    expect(score('xyz')).toBeNull()
  })

  it('ignores case, spaces and punctuation', () => {
    expect(matchScore('gpt6', model('gpt-6-astra', 'GPT-6 Astra'))?.strong).toBe(true)
    expect(matchScore('OPUS', opus)?.strong).toBe(true)
  })
})

describe('assemble', () => {
  const sections = modelSections({ models, tool: tool('veo', 'Veo', ['veo-4', 'veo-3']), category: video, saved: null })

  it('shows the always sections and counts what Show all adds', () => {
    const list = assemble(sections, '', false)
    expect(list.groups.map((group) => group.label)).toEqual(['Works with Veo', 'Other models for Video'])
    expect(list.hidden).toBe(2)
    expect(assemble(sections, '', true).groups.map((group) => group.label)).toContain('All models')
  })

  it('searches every section when a query is typed, best match first', () => {
    const list = assemble(sections, 'opus', false)
    expect(list.groups).toEqual([{ id: 'all', label: 'All models', options: [opus] }])
    expect(list.hidden).toBe(0)
    expect(slugs(assemble(sections, 'veo 3', false).groups[0]!.options)).toEqual(['veo-3', 'veo-4'])
  })
})

describe('canAdd', () => {
  it('offers Add for a 2 to 60 character name nothing matches by name, maker or slug', () => {
    const sections = modelSections({ models, tool: null, category: video, saved: null })
    const offer = (query: string) => canAdd(query, assemble(sections, query, false))

    expect(offer('Seedance 2')).toBe(true)
    expect(offer('kling')).toBe(false)
    expect(offer('k')).toBe(false)
    expect(offer('x'.repeat(61))).toBe(false)
  })
})

describe('modelForTool', () => {
  it('fills in the one model a tool runs', () => {
    expect(modelForTool(tool('jev', 'TypeSafe Jev', ['jev']), '')).toEqual({ model: 'jev' })
    expect(modelForTool(tool('jev', 'TypeSafe Jev', ['jev']), 'jev')).toEqual({})
  })

  it('clears a model the new tool does not run, and keeps one it does', () => {
    const veo = tool('veo', 'Veo', ['veo-4', 'veo-3'])
    expect(modelForTool(veo, 'claude-opus-5-5')).toEqual({ model: null })
    expect(modelForTool(veo, 'veo-3')).toEqual({})
    expect(modelForTool(veo, '')).toEqual({})
  })

  it('leaves the model alone for a tool the catalog pairs with nothing', () => {
    expect(modelForTool(tool('pika', 'Pika'), 'claude-opus-5-5')).toEqual({})
    expect(modelForTool(undefined, 'claude-opus-5-5')).toEqual({})
  })
})
