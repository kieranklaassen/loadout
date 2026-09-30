import type { Category, MarkItem } from '../types'
import { rankLabel } from './rank_label'
import { teamCountText, type CatalogOption, type EditorKind, type TeamStanding } from './ranking'

// What the Rank editor's Tool and Model pickers list, as pure functions of the props: the
// sections, in order, and how a typed query filters and ranks them. The Model picker
// follows the tool: the models the tool runs come first, then the other models suited to
// the kind, and everything else waits behind "Show all".

export const NAME_LENGTH = { min: 2, max: 60 }

/** One row a picker offers; `note` is a caption on its right, `disabled` keeps it listed but unpickable. */
export type PickerOption = CatalogOption & { note?: string; disabled?: boolean }

/** A section of a picker. `always` sections show before anything is typed; the rest wait behind "Show all". */
export type PickerSection = { id: string; label: string; options: PickerOption[]; always: boolean }

export type PickerList = {
  groups: { id: string; label: string; options: PickerOption[] }[]
  /** How many rows "Show all" would add; 0 once shown or while a query is typed. */
  hidden: number
  /** Whether any row matches the query by name, maker or slug rather than only loosely. */
  exact: boolean
}

const compact = (text: string) => text.toLowerCase().replace(/[^\p{L}\p{N}]+/gu, '')

/** How well `query` names `option`: higher is better, null is no match. `strong` is a real match, not a loose one. */
export function matchScore(query: string, option: Pick<CatalogOption, 'name' | 'slug' | 'maker'>): { score: number; strong: boolean } | null {
  const q = query.trim().toLowerCase()
  if (!q) return { score: 0, strong: true }

  const name = option.name.toLowerCase()
  const words = name.split(/[^\p{L}\p{N}.]+/u)
  const cq = compact(q)
  if (name === q) return { score: 100, strong: true }
  if (name.startsWith(q)) return { score: 90, strong: true }
  if (words.some((word) => word.startsWith(q))) return { score: 80, strong: true }
  if (name.includes(q) || (cq && compact(name).includes(cq))) return { score: 70, strong: true }
  if ([option.maker ?? '', option.slug].some((field) => field.toLowerCase().includes(q))) return { score: 50, strong: true }

  const loose = subsequence(cq, compact(name))
  return loose === null ? null : { score: 40 - loose, strong: false }
}

/** The letters of `query` in order inside `text`: returns how spread out they are, or null when they are not all there. */
function subsequence(query: string, text: string) {
  if (query.length < 2) return null
  let at = -1
  let gaps = 0
  for (const letter of query) {
    const next = text.indexOf(letter, at + 1)
    if (next === -1) return null
    if (at >= 0) gaps += next - at - 1
    at = next
  }
  return gaps > query.length * 2 ? null : gaps
}

/** The sections as a picker shows them: without a query the `always` ones (and the rest after "Show all"); with one, every match, best first within its section. */
export function assemble(sections: PickerSection[], query: string, showAll: boolean): PickerList {
  const q = query.trim()
  if (!q) {
    const shown = sections.filter((section) => (section.always || showAll) && section.options.length > 0)
    const hidden = showAll ? 0 : sections.filter((section) => !section.always).reduce((sum, section) => sum + section.options.length, 0)
    return { groups: shown.map(({ id, label, options }) => ({ id, label, options })), hidden, exact: true }
  }

  let exact = false
  const groups = sections
    .map(({ id, label, options }) => {
      const scored = options.flatMap((option, index) => {
        const match = matchScore(q, option)
        if (!match) return []
        if (match.strong) exact = true
        return [{ option, index, score: match.score }]
      })
      scored.sort((a, b) => b.score - a.score || a.index - b.index)
      return { id, label, options: scored.map(({ option }) => option) }
    })
    .filter((group) => group.options.length > 0)
  return { groups, hidden: 0, exact }
}

/** Whether "Add “name” as a suggestion" is offered: a name the right length that nothing matches by name, maker or slug. */
export function canAdd(query: string, list: PickerList) {
  const name = query.trim().replace(/\s+/g, ' ')
  return name.length >= NAME_LENGTH.min && name.length <= NAME_LENGTH.max && !list.exact
}

const suits = (option: CatalogOption, category: Category) => option.suggested_for.includes(category.slug)

/** Most-used on the team first, catalog order otherwise, with "4 of 6 use it" as the note. */
function byPopularity(options: CatalogOption[], standings: TeamStanding[] = []): PickerOption[] {
  const counts = new Map(standings.map((standing) => [standing.item.slug, standing]))
  return options
    .map((option, index) => ({ option, index, standing: counts.get(option.slug) }))
    .sort((a, b) => (b.standing?.count.n ?? 0) - (a.standing?.count.n ?? 0) || a.index - b.index)
    .map(({ option, standing }) => (standing ? { ...option, note: teamCountText(standing) } : option))
}

/**
 * The saved item is always in view: in its own section when it would otherwise wait behind
 * "Show all" (it suits another kind, or the catalog no longer lists it because an admin hid it).
 */
function withSaved(sections: PickerSection[], saved: MarkItem | null | undefined): PickerSection[] {
  if (!saved || sections.some((section) => section.always && section.options.some((option) => option.slug === saved.slug))) return sections

  const option = sections.flatMap((section) => section.options).find((candidate) => candidate.slug === saved.slug) ?? { ...saved, suggested_for: [] }
  const rest = sections.map((section) => ({ ...section, options: section.options.filter((candidate) => candidate.slug !== saved.slug) }))
  return [{ id: 'current', label: 'Current', options: [option], always: true }, ...rest]
}

export function toolSections({ tools, kind, rank, saved, standings }: {
  tools: CatalogOption[]
  kind: EditorKind
  rank: number
  saved: MarkItem | null | undefined
  standings?: TeamStanding[]
}): PickerSection[] {
  const elsewhere = new Map(kind.picks.filter((pick) => pick.rank !== rank).map((pick) => [pick.tool.slug, pick.rank]))
  const mark = (option: PickerOption): PickerOption => {
    const at = elsewhere.get(option.slug)
    return at ? { ...option, disabled: true, note: `Your ${rankLabel(at)} pick` } : option
  }
  const approved = tools.filter((tool) => !tool.pending)

  return withSaved(
    [
      { id: 'kind', label: `Suggested for ${kind.category.name}`, options: byPopularity(approved.filter((tool) => suits(tool, kind.category)), standings).map(mark), always: true },
      { id: 'yours', label: 'Added by you', options: tools.filter((tool) => tool.pending).map(mark), always: true },
      { id: 'all', label: 'All tools', options: approved.filter((tool) => !suits(tool, kind.category)).map(mark), always: false },
    ],
    saved,
  )
}

export function modelSections({ models, tool, category, saved, standings }: {
  models: CatalogOption[]
  tool: CatalogOption | null | undefined
  category: Category
  saved: MarkItem | null | undefined
  standings?: TeamStanding[]
}): PickerSection[] {
  const approved = models.filter((model) => !model.pending)
  const bySlug = new Map(approved.map((model) => [model.slug, model]))
  const paired = (tool?.models ?? []).flatMap((slug) => bySlug.get(slug) ?? [])
  const suited = paired.filter((model) => suits(model, category))
  const first = suited.length > 0 ? suited : paired
  const taken = new Set(first.map((model) => model.slug))
  const forKind = byPopularity(approved.filter((model) => suits(model, category) && !taken.has(model.slug)), standings)
  forKind.forEach((model) => taken.add(model.slug))

  return withSaved(
    [
      ...(tool && first.length > 0 ? [{ id: 'tool', label: `Works with ${tool.name}`, options: first, always: true }] : []),
      { id: 'kind', label: first.length > 0 ? `Other models for ${category.name}` : `Suggested for ${category.name}`, options: forKind, always: true },
      { id: 'yours', label: 'Added by you', options: models.filter((model) => model.pending), always: true },
      { id: 'all', label: 'All models', options: approved.filter((model) => !taken.has(model.slug)), always: false },
    ],
    saved,
  )
}

/**
 * What choosing a tool also does to the model: a tool that runs exactly one model fills it
 * in, and a catalog model the new tool does not run is cleared. A tool the catalog pairs
 * with nothing leaves the model alone, and so does a model the catalog cannot vouch for
 * (the member's own, pending review, or one an admin hid).
 */
export function modelForTool(tool: CatalogOption | undefined, model: CatalogOption | undefined): { model?: string | null } {
  const paired = tool?.models ?? []
  if (paired.length === 1) return paired[0] === model?.slug ? {} : { model: paired[0] }
  if (paired.length > 1 && model && !model.pending && !paired.includes(model.slug)) return { model: null }
  return {}
}
