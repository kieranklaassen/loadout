import type { CatalogKind, MarkItem, RankedPick, Suggestion } from '../types'

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
