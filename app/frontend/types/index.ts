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
  visibility: Visibility
  email_verified: boolean
  onboarded: boolean
}

export type SharedProps = {
  current_user: CurrentUser | null
  flash: FlashData
  /** Display host for links and the footer; read it through usePublicHost(). */
  public_host?: string
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

/** A catalog item as the admin review page receives it. Launch fields are models only; the creator is shown only while an item is pending. */
export type AdminCatalogItem = MarkItem & {
  id: number
  maker: string | null
  status: CatalogStatus
  family: string | null
  released_on?: string | null
  vibe_check_url?: string | null
  created_by: { name: string; handle: string | null } | null
  created_at: string
}

export type MergeTarget = { id: number; name: string }

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

// Every dark redesign: shapes shared by several pages (plan Contracts). Page-specific
// props live in their page file. The v1 types above stay until U13.

export type Visibility = 'only_me' | 'team' | 'link'

/** A tool or a model as the Every dark pages show it: `mark` is a key in assets/marks, or null for a serif initial. */
export type MarkItem = {
  slug: string
  name: string
  kind: CatalogKind
  mark: string | null
  pending: boolean
}

/** "N of M": one definition on every surface (R15). */
export type Count = {
  n: number
  of: number
}

export type PickContext = '200k' | '1m'
export type PickEffort = 'low' | 'medium' | 'high'

/** One confirmed pick at rank 1 to 3. (Not `Pick`: that is a TypeScript utility type.) */
export type RankedPick = {
  rank: number
  tool: MarkItem
  model: MarkItem | null
  context: PickContext | null
  effort: PickEffort | null
}

/** An agent's proposed pick, waiting for its owner to confirm it in the Rank editor. */
export type Suggestion = {
  id: number
  category: string
  tool: MarkItem
  model: MarkItem | null
  context: PickContext | null
  effort: PickEffort | null
  slot_hint: number | null
  /** The slot it would land in; null when the kind is full and the member picks the pick to replace. */
  target_rank: number | null
  replaces: { rank: number; tool: MarkItem; model: MarkItem | null } | null
  suggested_by: string
  suggested_at: string
}

/** A stretch of time the team's number-one tool and model stayed the same; `to` is null for the current era. */
export type Era = {
  from: string
  to: string | null
  tool: MarkItem
  /** Null while nobody counted had a model. */
  model: MarkItem | null
}

export type Launch = {
  model: MarkItem
  released_on: string
  vibe_check_url: string
  newest: boolean
  adoption: Count
  mostly_in: MarkItem | null
}
