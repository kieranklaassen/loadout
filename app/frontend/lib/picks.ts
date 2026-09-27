import type { CatalogItem, LoadoutPick, PicksByCategory, ReplaceCategoryOperation } from '../types'

export const NOTE_LIMIT = 280

export function itemKey(item: Pick<CatalogItem, 'slug' | 'name'>) {
  return item.slug || `new:${item.name.trim().toLowerCase()}`
}

export function sameItem(a: CatalogItem | null, b: CatalogItem | null) {
  if (!a || !b) return a === b
  return itemKey(a) === itemKey(b)
}

export function pickKey(pick: LoadoutPick) {
  return `${itemKey(pick.tool)}|${pick.model ? itemKey(pick.model) : ''}`
}

/** A tool or model the member typed that isn't in the catalog yet. Saved as pending. */
export function draftItem(name: string): CatalogItem {
  const clean = name.trim().replace(/\s+/g, ' ')
  const words = clean.match(/[\p{L}\p{N}]+/gu) ?? []
  const [first = '?', second] = words
  const letters = second ? first.charAt(0) + second.charAt(0) : first.slice(0, 2)
  const monogram = letters.charAt(0).toUpperCase() + letters.slice(1).toLowerCase()
  let hue = 0
  for (const char of clean.toLowerCase()) hue = (hue * 31 + char.charCodeAt(0)) % 360
  return { slug: '', name: clean, maker: null, hue, monogram, pending: true }
}

export function hasTool(picks: LoadoutPick[], tool: CatalogItem) {
  return picks.some((pick) => sameItem(pick.tool, tool))
}

function withOnePrimary(picks: LoadoutPick[]) {
  if (picks.length === 0 || picks.some((pick) => pick.primary)) return picks
  return picks.map((pick, index) => (index === 0 ? { ...pick, primary: true } : pick))
}

/** Taps a tool on or off. The first pick in a category becomes the go-to. */
export function toggleTool(picks: LoadoutPick[], tool: CatalogItem): LoadoutPick[] {
  if (hasTool(picks, tool)) return withOnePrimary(picks.filter((pick) => !sameItem(pick.tool, tool)))
  return [...picks, { tool, model: null, primary: picks.length === 0, note: null }]
}

/** Picks a model for a pick; choosing the current model again clears it. */
export function setModel(picks: LoadoutPick[], index: number, model: CatalogItem | null): LoadoutPick[] {
  return picks.map((pick, i) => (i === index ? { ...pick, model: sameItem(pick.model, model) ? null : model } : pick))
}

export function makePrimary(picks: LoadoutPick[], index: number): LoadoutPick[] {
  return picks.map((pick, i) => ({ ...pick, primary: i === index }))
}

export function setNote(picks: LoadoutPick[], index: number, note: string): LoadoutPick[] {
  return picks.map((pick, i) => (i === index ? { ...pick, note: note.slice(0, NOTE_LIMIT) } : pick))
}

export function removePick(picks: LoadoutPick[], index: number): LoadoutPick[] {
  return withOnePrimary(picks.filter((_, i) => i !== index))
}

/** Catalog search: name or maker contains the query, name-prefix matches first. */
export function searchItems(items: CatalogItem[], query: string, limit = 6): CatalogItem[] {
  const q = query.trim().toLowerCase()
  if (!q) return []
  const matches = items.filter(
    (item) => item.name.toLowerCase().includes(q) || (item.maker ?? '').toLowerCase().includes(q),
  )
  const rank = (item: CatalogItem) => (item.name.toLowerCase().startsWith(q) ? 0 : item.name.toLowerCase().includes(q) ? 1 : 2)
  return matches.sort((a, b) => rank(a) - rank(b)).slice(0, limit)
}

function serialize(picks: LoadoutPick[] | undefined) {
  return JSON.stringify(
    (picks ?? []).map((pick) => [pickKey(pick), pick.primary, (pick.note ?? '').trim()]),
  )
}

/** Categories whose picks differ from what was saved, in the given order. */
export function changedCategories(saved: PicksByCategory, current: PicksByCategory, order: string[]) {
  return order.filter((slug) => serialize(saved[slug]) !== serialize(current[slug]))
}

export function toOperations(picks: PicksByCategory, categories: string[]): ReplaceCategoryOperation[] {
  return categories.map((category) => ({
    op: 'replace_category',
    category,
    picks: (picks[category] ?? []).map((pick) => ({
      tool: pick.tool.slug || pick.tool.name,
      model: pick.model ? pick.model.slug || pick.model.name : null,
      primary: pick.primary,
      note: pick.note?.trim() || null,
    })),
  }))
}

export function countPicks(picks: PicksByCategory) {
  const lists = Object.values(picks).filter((list) => list.length > 0)
  return { picks: lists.reduce((sum, list) => sum + list.length, 0), categories: lists.length }
}
