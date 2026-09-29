import type { HomeFilters } from '../components/team/filters'
import type { HeroData } from '../components/team/hero'
import type { PersonData } from '../components/team/person_view'
import type { WhatWeUseRow } from '../components/team/what_we_use_table'
import type { Category, Launch } from '../types'
import { claudeCodeMark, cursorMark, markItem, opusMark, rankedPick } from './picker_fixtures'

export const codingKind: Category = { slug: 'coding', name: 'Coding', blurb: 'Writing and shipping software' }
export const writingKind: Category = { slug: 'writing', name: 'Writing', blurb: 'Drafting and editing text' }
export const musicKind: Category = { slug: 'music', name: 'Music', blurb: 'Making music and sound' }

export const claudeMark = markItem('claude', 'Claude', 'tool', 'claude')
export const gptMark = markItem('gpt-6-astra', 'GPT-6 Astra', 'model', 'openai')

export const homeFilters = (overrides: Partial<HomeFilters> = {}): HomeFilters => ({ show: 'team', person: null, overall: false, q: null, ...overrides })

export const codingRow = (overrides: Partial<WhatWeUseRow> = {}): WhatWeUseRow => ({
  category: codingKind,
  top_tool: { item: claudeCodeMark, count: { n: 5, of: 6 }, runner_up: { item: cursorMark, count: { n: 2, of: 6 } } },
  top_model: { item: opusMark, count: { n: 4, of: 6 }, runner_up: { item: gptMark, count: { n: 2, of: 6 } } },
  ranked: { n: 6, of: 6 },
  last_update_at: '2026-09-19T12:00:00Z',
  stale: false,
  ...overrides,
})

export const launch = (overrides: Partial<Launch> = {}): Launch => ({
  model: opusMark,
  released_on: '2026-09-22',
  vibe_check_url: 'https://checks.every.to/vibe-checks/claude-opus-5-5',
  newest: true,
  adoption: { n: 4, of: 6 },
  mostly_in: claudeCodeMark,
  ...overrides,
})

export const heroData = (overrides: Partial<HeroData> = {}): HeroData => ({
  boards: [
    {
      category: codingKind,
      picks: [
        { rank: 1, tool: claudeCodeMark, model: opusMark },
        { rank: 2, tool: cursorMark, model: null },
      ],
    },
    { category: writingKind, picks: [{ rank: 1, tool: claudeMark, model: opusMark }] },
    { category: musicKind, picks: [{ rank: 1, tool: cursorMark, model: null }] },
  ],
  people: 6,
  picks: 30,
  last_update_at: '2026-09-19T12:00:00Z',
  ...overrides,
})

export const personData = (overrides: Partial<PersonData> = {}): PersonData => ({
  person: { handle: 'dan', name: 'Dan', avatar_url: null },
  ranked_count: 2,
  kinds: [
    {
      category: codingKind,
      picks: [
        rankedPick({ rank: 1, tool: claudeCodeMark, model: opusMark, context: '1m', effort: 'high' }),
        rankedPick({ rank: 2, tool: cursorMark, model: null }),
      ],
      team_uses: { tool: claudeMark, model: null },
    },
    { category: writingKind, picks: [rankedPick({ rank: 1, tool: claudeMark, model: opusMark })], team_uses: null },
    { category: musicKind, picks: [], team_uses: null },
  ],
  new_in_toolbox: [launch()],
  ...overrides,
})
