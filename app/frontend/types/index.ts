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

/** One row of an Every map ranking: a tool or model, how many people use it, and who is named. */
export type MapRank = {
  item: CatalogItem
  count: number
  share: number
  people: ProfileSummary[]
  others_count: number
  in_loadout: boolean
  usual_model?: CatalogItem | null
}

export type MapPanel = {
  category: Category
  people_count: number
  tools_count: number
  models_count: number
  tools: MapRank[]
  models: MapRank[]
}

export type MapSummary = {
  members: number
  picks: number
  tools: number
  categories: number
}

export type MapUpgrade = {
  category: Category
  tool: CatalogItem
  from_model: CatalogItem
  to_model: CatalogItem
  colleagues_count: number
}

export type MapDiscovery = {
  empty_categories: { category: Category; people_count: number; tools: MapRank[] }[]
  upgrades: MapUpgrade[]
}

export type MapPerson = ProfileSummary & {
  picks: { tool: CatalogItem; model: CatalogItem | null; primary: boolean }[]
}

export type CatalogKind = 'tool' | 'model'
export type CatalogStatus = 'approved' | 'pending' | 'hidden'

/** A catalog item as the admin review page receives it. */
export type AdminCatalogItem = CatalogItem & {
  id: number
  kind: CatalogKind
  status: CatalogStatus
  family: string | null
  people: number
  created_by: { name: string; handle: string | null } | null
  created_at: string
}

export type MergeTarget = Pick<CatalogItem, 'name' | 'hue' | 'monogram'> & { id: number }

/** An MCP client the member approved, as the agents page receives it. */
export type ConnectedAgent = {
  id: string
  name: string
  hue: number
  monogram: string
  connected_at: string
  last_used_at: string | null
}

/** The OAuth authorization request the consent form posts back unchanged. */
export type OauthAuthorizationParams = {
  client_id: string
  redirect_uri: string
  response_type: 'code'
  code_challenge: string
  code_challenge_method: 'S256'
  state?: string
  resource?: string
  scope?: string
}
