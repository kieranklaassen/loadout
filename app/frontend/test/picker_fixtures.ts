import type { CatalogItem, CatalogKind, MarkItem, PickerCatalog, PickerCategory, RankedPick, Suggestion } from '../types'

const item = (slug: string, name: string, maker: string, hue = 220): CatalogItem => ({
  slug,
  name,
  maker,
  hue,
  monogram: name.slice(0, 2),
  pending: false,
})

export const cursor = item('cursor', 'Cursor', 'Anysphere')
export const claudeCode = item('claude-code', 'Claude Code', 'Anthropic', 18)
export const claude = item('claude', 'Claude', 'Anthropic', 18)
export const runway = item('runway', 'Runway', 'Runway', 345)
export const opus = item('claude-opus-5-5', 'Claude Opus 5.5', 'Anthropic', 18)
export const gpt = item('gpt-6-astra', 'GPT-6 Astra', 'OpenAI', 160)

export const catalog: PickerCatalog = {
  tools: [cursor, claudeCode, claude, runway],
  models: [opus, gpt],
}

export const coding: PickerCategory = {
  slug: 'coding',
  name: 'Coding',
  blurb: 'Writing, reviewing, and shipping code.',
  tool_slugs: ['cursor', 'claude-code'],
  model_slugs: ['claude-opus-5-5', 'gpt-6-astra'],
}

export const video: PickerCategory = {
  slug: 'video',
  name: 'Video',
  blurb: 'Generating and editing video.',
  tool_slugs: ['runway'],
  model_slugs: [],
}

// Every dark shapes (types/index.ts, plan Contracts).
export const markItem = (slug: string, name: string, kind: CatalogKind = 'tool', mark: string | null = null): MarkItem => ({
  slug,
  name,
  kind,
  mark,
  pending: false,
})

export const claudeCodeMark = markItem('claude-code', 'Claude Code', 'tool', 'claudecode')
export const cursorMark = markItem('cursor', 'Cursor', 'tool', 'cursor')
export const opusMark = markItem('claude-opus-5-5', 'Claude Opus 5.5', 'model', 'claude')

export const rankedPick = (overrides: Partial<RankedPick> = {}): RankedPick => ({
  rank: 1,
  tool: claudeCodeMark,
  model: opusMark,
  context: null,
  effort: null,
  ...overrides,
})

export const suggestion = (overrides: Partial<Suggestion> = {}): Suggestion => ({
  id: 1,
  category: 'coding',
  tool: cursorMark,
  model: null,
  context: null,
  effort: null,
  slot_hint: null,
  target_rank: null,
  replaces: null,
  suggested_by: 'Claude',
  suggested_at: '2026-09-20T12:00:00Z',
  ...overrides,
})
