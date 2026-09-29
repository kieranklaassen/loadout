import type { Listing, Person } from '../components/kind/ranked_list'
import type { Setup } from '../components/kind/setups'
import type { Take } from '../components/kind/takes'
import type { Count, Era, MarkItem } from '../types'
import { claudeMark, codingKind, gptMark } from './home_fixtures'
import { claudeCodeMark, cursorMark, opusMark } from './picker_fixtures'

export { codingKind }

export const kieran: Person = { handle: 'kieran', name: 'Kieran' }
export const dan: Person = { handle: 'dan', name: 'Dan' }
export const rob: Person = { handle: 'rob', name: 'Rob' }

/** A tool or model with N of M and the people at each rank (1st, 2nd, 3rd). */
export const listing = (item: MarkItem, count: Count, byRank: Record<number, Person[]>): Listing => ({
  item,
  count,
  by_rank: { 1: [], 2: [], 3: [], ...byRank },
})

export const tools = [
  listing(claudeCodeMark, { n: 3, of: 6 }, { 1: [kieran, dan], 2: [rob] }),
  listing(cursorMark, { n: 2, of: 6 }, { 2: [dan], 3: [kieran] }),
]

export const models = [listing(opusMark, { n: 3, of: 6 },{ 1: [kieran, dan], 3: [rob] }), listing(gptMark, { n: 2, of: 6 }, { 2: [rob, dan] })]

export const setups: Setup[] = [
  { tool: claudeCodeMark, model: opusMark, context: '1m', effort: 'high', count: { n: 2, of: 6 } },
  { tool: cursorMark, model: gptMark, context: null, effort: 'medium', count: { n: 1, of: 6 } },
  { tool: claudeMark, model: opusMark, context: null, effort: null, count: { n: 1, of: 6 } },
]

export const takes: Take[] = [{ model: opusMark, url: 'https://checks.every.to/vibe-checks/claude-opus-5-5' }]

export const eras: Era[] = [
  { from: '2025-02-03', to: '2025-04-30', tool: cursorMark, model: gptMark },
  { from: '2025-05-01', to: '2026-03-01', tool: claudeCodeMark, model: null },
  { from: '2026-03-02', to: null, tool: claudeCodeMark, model: opusMark },
]
