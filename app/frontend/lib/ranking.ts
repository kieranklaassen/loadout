import type { Category, Count, MarkItem, PickContext, PickEffort, RankedPick, Suggestion } from '../types'

// The Rank editor's shapes and the rules that place picks and suggestions in its three
// slots. Pure functions of the props, so the page, its sidebar and the team list agree.

export const MAX_RANK = 3
export const RANKS = [1, 2, 3]

export type EditorKind = {
  category: Category
  picks: RankedPick[]
  suggestions: Suggestion[]
  to_confirm: number
}

/** A catalog item the selects offer, with the kinds it suits. */
export type CatalogOption = MarkItem & { suggested_for: string[] }

export type Catalog = {
  tools: CatalogOption[]
  models: CatalogOption[]
}

export type Enums = {
  context: PickContext[]
  effort: PickEffort[]
}

export type TeamStanding = {
  item: MarkItem
  count: Count
  yours_rank: number | null
}

export type TeamTop = Record<string, { tools: TeamStanding[]; models: (TeamStanding & { launched: boolean })[] }>

const ORDINALS = ['1st', '2nd', '3rd']

export const ordinal = (rank: number) => ORDINALS[rank - 1] ?? `${rank}th`

export const contextOptionLabel = (context: PickContext) => context.toUpperCase()

export const effortOptionLabel = (effort: PickEffort) => effort.charAt(0).toUpperCase() + effort.slice(1)

export type SlotView = {
  rank: number
  pick: RankedPick | null
  /** Open suggestions that would land in this slot: an empty one, or a change to its pick. */
  suggestions: Suggestion[]
}

/** The three slots in order, and the suggestions the full kind has no slot for. */
export function layoutSlots(kind: EditorKind): { slots: SlotView[]; unplaced: Suggestion[] } {
  return {
    slots: RANKS.map((rank) => ({
      rank,
      pick: kind.picks.find((pick) => pick.rank === rank) ?? null,
      suggestions: kind.suggestions.filter((suggestion) => suggestion.target_rank === rank),
    })),
    unplaced: kind.suggestions.filter((suggestion) => suggestion.target_rank === null),
  }
}

/** Slots that hold a pick or would hold a suggestion (a slot counts once, however many stack in it), and every open suggestion. */
export function progress(kind: EditorKind) {
  const filled = new Set(kind.picks.map((pick) => pick.rank))
  kind.suggestions.forEach((suggestion) => suggestion.target_rank !== null && filled.add(suggestion.target_rank))
  return { filled: Math.min(MAX_RANK, filled.size), toConfirm: kind.suggestions.length }
}

export function progressLabel(kind: EditorKind) {
  const { filled, toConfirm } = progress(kind)
  if (filled === 0 && toConfirm === 0) return 'Not started'
  return toConfirm > 0 ? `${filled} of ${MAX_RANK} · ${toConfirm} to confirm` : `${filled} of ${MAX_RANK}`
}

export const startedCount = (kinds: EditorKind[]) => kinds.filter((kind) => progress(kind).filled > 0).length

export const firstEmptyRank = (kind: EditorKind) => RANKS.find((rank) => !kind.picks.some((pick) => pick.rank === rank)) ?? null

export type TeamAction = { type: 'have'; text: string } | { type: 'use'; label: string; rank: number }

const trying = (n: number) => (n === 1 ? 'is trying it' : 'are trying it')
const using = (n: number) => (n === 1 ? 'uses it' : 'use it')

/** "5 of 6 use it", or "New · 2 of 6 are trying it" for a launched model. */
export function teamCountText(standing: TeamStanding, launched = false) {
  const { n, of } = standing.count
  return launched ? `New · ${n} of ${of} ${trying(n)}` : `${n} of ${of} ${using(n)}`
}

/** What a team-list tool row offers: nothing on a full kind, else "You have it 1st" or a button for the first empty slot. */
export function toolAction(kind: EditorKind, standing: TeamStanding): TeamAction | null {
  const own = kind.picks.find((pick) => pick.tool.slug === standing.item.slug)
  if (own) return { type: 'have', text: `You have it ${ordinal(own.rank)}` }

  const rank = firstEmptyRank(kind)
  return rank ? { type: 'use', label: `Use as ${ordinal(rank)} pick`, rank } : null
}

/** A model row: "You use it", or a button for the first pick that has a tool and no model. A model needs a tool, so an empty slot never qualifies. */
export function modelAction(kind: EditorKind, standing: TeamStanding): TeamAction | null {
  if (kind.picks.some((pick) => pick.model?.slug === standing.item.slug)) return { type: 'have', text: 'You use it' }
  if (kind.picks.length >= MAX_RANK) return null

  const target = kind.picks.find((pick) => !pick.model)
  return target ? { type: 'use', label: `Use in ${ordinal(target.rank)} pick`, rank: target.rank } : null
}

/** A select's options: those that suit the kind first, then the rest. The saved item stays offered even if the catalog no longer lists it. */
export function optionGroups(options: CatalogOption[], category: string, saved: MarkItem | null) {
  const all = saved && !options.some((option) => option.slug === saved.slug) ? [...options, { ...saved, suggested_for: [] }] : options
  return {
    suggested: all.filter((option) => option.suggested_for.includes(category)),
    rest: all.filter((option) => !option.suggested_for.includes(category)),
  }
}

/** The slugs of the tools the other slots of the kind already use. */
export const toolsUsedElsewhere = (kind: EditorKind, rank: number) =>
  new Set(kind.picks.filter((pick) => pick.rank !== rank).map((pick) => pick.tool.slug))

/** What a screen reader hears after a row changes. */
export const movedMessage = (name: string, rank: number) => `${name} is now ${ordinal(rank)}`
