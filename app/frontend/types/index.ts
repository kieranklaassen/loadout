export type FlashData = {
  notice?: string
  alert?: string
}

export type CurrentUser = {
  id: number
  name: string
  handle: string | null
  avatar_url: string | null
  every_member: boolean
  admin: boolean
  public: boolean
  onboarded: boolean
}

export type SharedProps = {
  current_user: CurrentUser | null
  flash: FlashData
}

/** A tool (Cursor, Claude Code, Runway) or a model (Claude Opus 5.5) as pages receive it. */
export type CatalogItem = {
  slug: string
  name: string
  maker: string | null
  hue: number
  monogram: string
  pending?: boolean
}

export type Category = {
  slug: string
  name: string
  blurb: string
}

export type Entry = {
  id: number
  category: string
  tool: CatalogItem
  model: CatalogItem | null
  note: string | null
  primary: boolean
}

export type ChangeEvent = {
  id: number
  sentence: string
  action: 'added' | 'removed' | 'updated' | 'made_primary' | 'switched'
  source: 'web' | 'mcp' | 'webmcp'
  client_name: string | null
  created_at: string
}

export type ProfileSummary = {
  handle: string
  name: string
  avatar_url: string | null
}

/** The member a profile page is about. */
export type ProfileDetail = {
  handle: string
  name: string
  avatar_url: string | null
  bio: string | null
  every_member: boolean
  public: boolean
  url: string
  display_url: string
}

export type LoadoutCategory = Category & {
  entries: Entry[]
}

/** A category as the pickers receive it, with suggested tools and models first. */
export type PickerCategory = Category & {
  tool_slugs: string[]
  model_slugs: string[]
}

export type PickerCatalog = {
  tools: CatalogItem[]
  models: CatalogItem[]
}

/** One pick in a picker. A tool or model typed by name has an empty slug until saved. */
export type LoadoutPick = {
  tool: CatalogItem
  model: CatalogItem | null
  primary: boolean
  note: string | null
}

export type PicksByCategory = Record<string, LoadoutPick[]>

export type PickerData = {
  categories: PickerCategory[]
  catalog: PickerCatalog
  picks: PicksByCategory
}

/** The `replace_category` shape PATCH /loadout accepts (see Loadouts::Update). */
export type ReplaceCategoryOperation = {
  op: 'replace_category'
  category: string
  picks: { tool: string; model: string | null; primary: boolean; note: string | null }[]
}

export type HandleAvailability = {
  handle: string
  available: boolean
  message: string
}
