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
  /** Where the hidden frame of an automatic sign-in goes; null when no attempt is due. */
  silent_sign_in_path: string | null
}

export type Category = {
  slug: string
  name: string
  blurb: string
}

export type HandleAvailability = {
  handle: string
  available: boolean
  message: string
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

// Shapes shared by several pages. Page-specific props live in their page file.

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
