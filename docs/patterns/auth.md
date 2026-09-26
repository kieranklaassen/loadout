# Authentication Approach

## Summary

Two distinct auth lineages run across these projects, split by app age/origin. The **newer, hand-built Rails 8 apps** (Tada, Diskman, Thinkroom, Riffrec-dashboard) all converge on the exact same pattern: `has_secure_password` on `User`, a DB-backed `Session` model (or, in Thinkroom's case, a bare `session[:user_id]` cookie), a `cookies.signed.permanent[:session_id]` httponly cookie, and an `Authentication`/`AuthenticatesUser` controller concern that is close to byte-identical across Tada and Diskman — this is clearly Rails 8.1's stock `bin/rails generate authentication` output, lightly adapted per app. OmniAuth (Google, Spotify, Discord) is layered on top only for *linking external accounts* (Spotify listening data, Google Calendar/Gmail, Discord roles) or as an alternate login method (Thinkroom's Google sign-in), never as the sole identity mechanism in these apps. The **older, Jumpstart-Pro-derived apps** (Cora, Lifegarden, erf-rails — erf-rails being the vendored Jumpstart Pro template itself) instead use Devise (`database_authenticatable, registerable, recoverable, rememberable, validatable, confirmable, omniauthable`) with a `User::Authenticatable` concern, Devise 2FA (`otp_required_for_login`), Devise-invitable-style invitation columns, and a Jumpstart `Account`/`AccountUser` multi-tenancy model with roles. Two apps sit outside both lineages: Every is a legacy Rails app with fully hand-rolled magic-link auth (`login_hash` token + email, `cookies.encrypted[:user_id]`) plus Google/Discord OAuth; Atelier is Rails with **no login at all**, relying entirely on Tailscale-network identity. Leva and Blazer-ai are gems/engines with no `User` model of their own — they read `current_user`/`controller.current_user` from whatever host app installs them. kieranklaassen-com is a Rails marketing site with `bcrypt` commented out — no auth.

## Per-project breakdown

### cora
- Devise 5.0.3 + `devise-passwordless` + `jwt` (~2.8) + `omniauth-google-oauth2` + `omniauth-rails_csrf_protection`, per `Gemfile`.
- Vendors **Jumpstart Pro** as a local engine: `Gemfile` does `eval_gemfile "Gemfile.jumpstart"` and `require_relative "lib/jumpstart/lib/jumpstart/..."`.
- `app/models/user/authenticatable.rb`: `devise(:database_authenticatable, :registerable, :recoverable, :rememberable, :validatable, :magic_link_authenticatable, :confirmable, :omniauthable)`, includes `User::TwoFactorAuthentication`, `has_referrals`, `attr_readonly :admin`.
- `User` (`app/models/user.rb`) composes many concerns: `Accounts, Agreements, Authenticatable, Mentions, Notifiable, Searchable, Theme, Marketing, KitTaggable, UserTimezone` plus `Discard::Model`.
- `config/routes/users.rb`: `devise_for :users` with custom controllers for `omniauth_callbacks`, `passwords`, `registrations`, `sessions`, and `passwordless_sessions: "devise/passwordless/sessions"`; extra `devise_scope :user { get "session/otp" ... }`.
- `app/controllers/users/sessions_controller.rb` extends `Devise::SessionsController`, intercepts `#create` with `prepend_before_action :authenticate_with_two_factor` for OTP two-factor, uses `session[:otp_user_id]`.
- `app/controllers/users/omniauth_callbacks_controller.rb` extends `Devise::OmniauthCallbacksController`, `include Jumpstart::Omniauth::Callbacks` — handles connecting/logging in via Google OAuth for Gmail/Calendar access via `ConnectedAccount`.
- Multi-tenancy: `Account`/`AccountUser` (Jumpstart pattern), multiple accounts per user (personal + team).
- `config/initializers/session_store.rb`: `cookie_store`, key `_cora_session`, `domain: :all, tld_length: 2` in non-dev.
- Auth logic lives in: `app/models/user/authenticatable.rb`, `app/models/concerns/user_timezone.rb`, `app/controllers/users/*`, `app/controllers/dev_sessions_controller.rb` (dev-only bypass).

### atelier
- Rails 8 + Inertia + React, **no database** ("the erf layer is file-backed" per `README.md`).
- `README.md` states explicitly: "Atelier has no login of its own and every surface is privileged." Access control happens at the network layer only: Puma/ttyd bind `127.0.0.1`, remote access goes through `tailscale serve`, and requests are allowed only when the Tailscale login is in `ATELIER_ALLOWED_LOGINS` and the device is in `ATELIER_ALLOWED_DEVICES` (set in `.env.appliance`). No `User` model, no session controller, no Devise/has_secure_password anywhere in `app/models` or `app/controllers` (checked — none present).
- Auth approach: **network identity via Tailscale, not app-level authentication.**

### tada
- Rails 8.1 + Inertia + React monolith (`README.md`).
- `app/models/user.rb`: `has_secure_password`, `has_many :sessions, dependent: :destroy`, `normalizes :email_address`, `validates :password, length: { minimum: 12 }`.
- `app/models/session.rb`: plain `belongs_to :user`, `belongs_to :active_child, class_name: "Child", optional: true` — DB-backed session row, not a cookie-only session.
- `app/controllers/concerns/authentication.rb`: stock Rails 8 generator pattern — `before_action :require_authentication`, `resume_session` looks up `Session.find_by(id: cookies.signed[:session_id])`, `start_new_session_for(user)` creates `user.sessions.create!` and sets `cookies.signed.permanent[:session_id]` (`httponly: true, same_site: :lax`).
- `app/controllers/sessions_controller.rb`: `User.authenticate_by(params.permit(:email_address, :password))`, `rate_limit to: 10, within: 3.minutes`.
- No OmniAuth for human login. Separately, Tada is itself an **OAuth 2.0 provider** for MCP clients: `app/controllers/oauth/{authorizations,registrations,tokens,metadata}_controller.rb`, `app/models/{oauth_client,oauth_grant,oauth_access_token,oauth_pending_authorization}.rb`.
- No multi-tenancy beyond `User has_many :children` (family-scoped, single owning `User` per family).

### diskman
- `app/models/user.rb`: `has_secure_password`, `has_many :sessions, dependent: :destroy`, `has_one_attached :avatar`, `normalizes :email_address`.
- `app/controllers/concerns/authentication.rb` is **identical** to Tada's (same `resume_session`/`start_new_session_for`/`cookies.signed.permanent[:session_id]` pattern) — confirms a shared house template.
- `Gemfile`: `jwt` (>= 2.10), `omniauth-spotify` (~1.0), `omniauth-rails_csrf_protection` (~2.0) — used only to connect Spotify for playback/sync, not for login. `config/routes.rb`: `get "/auth/:provider/callback", to: "oauth_callbacks#create"`.
- `app/models/connected_service.rb`: `belongs_to :user`, `encrypts :access_token`/`:refresh_token`, unique per `(provider, user_id)` — pattern for storing linked-service OAuth tokens separate from primary auth.

### lifegarden
- Devise 5.0.4 + `devise-i18n` + `devise-guests`, per `Gemfile`.
- `app/models/concerns/user/authenticatable.rb`: `devise(*[:database_authenticatable, :registerable, :recoverable, :rememberable, :validatable, :confirmable, (:omniauthable if defined? OmniAuth)].compact)`, includes `TwoFactorAuthentication`, `before_create :skip_confirmation!`, `attr_readonly :admin` — same Jumpstart Pro shape as cora/erf-rails, no `:magic_link_authenticatable` here (cora added that on top).
- `app/models/user.rb` includes `User::Accounts, User::Agreements, User::Authenticatable, User::Theme`.
- `app/models/account_user.rb`: `belongs_to :account, counter_cache: true`, `belongs_to :user`, `roles: jsonb`, `include Rolified`, `ROLES = [:admin, :member]` — Jumpstart's Account/AccountUser multi-tenancy with role-based permissions.
- `config/routes.rb`: `devise_for :users, controllers: { registrations: "users/registrations", sessions: "users/sessions" }`; two-factor routes under `namespace :user`.
- `guest: boolean default(FALSE)` column present on `users` (via `devise-guests` gem) though not wired into the `Authenticatable` concern's devise module list observed.
- `config/initializers/session_store.rb`: cookie_store line commented out (defaults apply).

### thinkroom
- `app/models/user.rb`: `has_secure_password validations: false`, custom `MINIMUM_PASSWORD_LENGTH = 10`, `MAXIMUM_PASSWORD_BYTES = 72` (guards bcrypt's silent 72-byte truncation — called out explicitly in riffrec-dashboard's code comments as "thinkroom hand-rolls a `password_within_bcrypt_limit`").
- `app/controllers/sessions_controller.rb`: manual `BCrypt::Password.new(digest).is_password?` check against a `DUMMY_PASSWORD_DIGEST` constant when no user is found (timing-attack mitigation), `user.password_account?` gate.
- **Not** the Session-AR-model pattern: `app/controllers/concerns/authenticates_user.rb#complete_authentication` does `reset_session; session[:user_id] = user.id` — a plain signed Rails cookie session, no `Session` table.
- `app/controllers/oauth_callbacks_controller.rb`: handles `omniauth.auth` for `google_oauth2`, matches by `google_uid`, creates `User` on first Google login if no email collision, checks `email_verified` from Google's `id_info`/`raw_info`. `omniauth-google-oauth2` (~1.2) in `Gemfile`.
- Native-app awareness: `native_app?`/`native_oauth_flow?` extend session lifetime for the RubyNative-wrapped app via a signed cookie from `RubyNative::OAuthMiddleware`.
- Also runs a separate CLI device-auth flow: `app/controllers/api/cli/sessions_controller.rb`, `cli_access_tokens`, `cli_device_authorizations` associations on `User`.

### riffrec-dashboard
- `app/models/user.rb`: `has_secure_password`; extensive code comments document deliberate design decisions (referenced as "KTD" numbers): **no registration route** — `bin/rails users:create` is the sole writer, explicitly to keep "the set of users IS the allowlist" and avoid a second writer reachable from the open internet (KTD4) — i.e., OAuth login was deliberately rejected here.
- `app/controllers/sessions_controller.rb`: generic `GENERIC_FAILURE = "Invalid email or password."` for both unknown-email and wrong-password cases (byte-identical, per R3 comment), `rate_limit to: 10, within: 3.minutes` using an explicitly-owned `RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new` (comment explains `rate_limit`'s default `store:` is captured at class-body eval time, so it must be pinned, not left to `Rails.cache`).
- `app/controllers/concerns/authenticates_user.rb`: same generator-derived session gate pattern as Tada/Diskman (`require_authentication` default-on for Inertia controllers).
- Separate machine identity: `app/controllers/concerns/authenticates_client.rb` — bearer-token auth for a server-to-server API, `Client.authenticate` looks up a SHA256 `api_key_digest` (or `previous_api_key_digest`, so rotation isn't an outage) — no plaintext secret ever compared.
- This is the clearest documented **house rationale** in the survey for keeping auth minimal and rejecting OAuth/registration by default.

### every
- Legacy hand-rolled auth, no Devise, no `has_secure_password` on `User`.
- `app/controllers/sessions_controller.rb#create`: **magic-link flow** — looks up `User` by lowercased email, sets `user.login_hash = SecureRandom.hex(32)`, emails `UserMailer.login_email` with the link; `#verify` finds `User.find_by(login_hash: params[:hash])` and sets `cookies.encrypted[:user_id] = { value: user.id, expires: 1.year.from_now }` plus a `bypass_cache` cookie.
- `#google_auth`: `User.from_omniauth(access_token)` stores `google_token`/`google_refresh_token` on the user and sets the same encrypted `user_id` cookie — Google OAuth is an alternate login path here, not account linking only.
- Discord OAuth also present for account linking (`unlinked_discord_user.rb`, `omniauth-discord` in `Gemfile`).
- `#logout`: `reset_session` + delete `user_id`/`bypass_cache` cookies.
- No `Session` model, no Devise — identity is carried entirely by the encrypted `user_id` cookie.

### erf-rails
- This **is** the Jumpstart Pro Rails template itself (`README.md`: "🎉 Jumpstart Pro Rails... clone the repository..."), vendored as `lib/jumpstart` — the canonical source Cora and Lifegarden derive their auth stack from.
- `app/models/user.rb`: `include Accounts, Agreements, Authenticatable, Mentions, Notifiable, Profile, Searchable, Theme`.
- `lib/jumpstart/app/models/user/authenticatable.rb` is the unmodified Devise setup other apps in this survey adapted.
- `config/routes/users.rb`: `devise_for :users` (multiple controller overrides, same shape as cora/lifegarden).
- `config/initializers/session_store.rb`: cookie_store line commented out, key would default to `_jumpstart_session`.

### kieranklaassen-com
- Rails 8.1 (Bridgetown-flavored static/content site — `.bridgetown-cache` present). `Gemfile`: `# gem "bcrypt", "~> 3.1.7"` is **commented out**; no `bcrypt`, no Devise, no OmniAuth. No `User` model found (`app/models/user*` — none).
- Auth approach: **none present** — this is a public content/marketing site with no login.

### leva
- Rails engine/gem (`leva.gemspec`), not a standalone app — no `app/models/user.rb` of its own.
- `README.md` shows it reads the host app's authentication: `config.authorize_fine_tune = ->(controller) { controller.current_user&.admin? }` — expects the mounting app to supply `current_user`/`admin?`.
- Auth approach: **delegates entirely to host app**; not present as its own concern.

### blazer-ai
- Also a Rails engine/gem (`blazer-ai.gemspec`), no `User` model, no auth of its own. README references "a read-only database user" for SQL execution safety, unrelated to web auth.
- Auth approach: **not present** — delegates to host app (Blazer's own auth, if any).

## Recommendation for compound-stack-rails

1. **Adopt the Rails 8 generator pattern (`has_secure_password` + DB-backed `Session` model + `cookies.signed.permanent[:session_id]`) as the default**, not Devise. This is what every actively-developed, from-scratch app in the survey (Tada, Diskman, Thinkroom, Riffrec-dashboard) independently converged on, and Tada's and Diskman's `app/controllers/concerns/authentication.rb` are near-identical — it's already the de facto house standard for new Rails 8 + Inertia work. Devise only appears in the Jumpstart-Pro-derived lineage (Cora, Lifegarden, erf-rails), which is a heavier, older template with its own multi-tenancy/2FA/invitation baggage that compound-stack-rails does not need to inherit.
2. **Ship a `Session` AR model, not a bare `session[:user_id]` cookie.** Tada/Diskman/Riffrec-dashboard's DB-backed sessions (`user_agent`, `ip_address` columns) enable per-device sign-out and audit, which Thinkroom's and Every's plain cookie approach cannot do. Riffrec-dashboard's comments show this is a considered choice, not an accident.
3. **Guard bcrypt's 72-byte truncation explicitly.** Thinkroom's `MAXIMUM_PASSWORD_BYTES = 72` validation and riffrec-dashboard's comment about it (referencing Thinkroom by name) show this is a known house gotcha worth baking into the starter's `User` model from day one.
4. **Treat OmniAuth as account-linking, not primary login, by default** — but make it a drop-in option. Diskman (Spotify) and Every (Discord) use OmniAuth purely to connect external services via a separate `ConnectedService`/linked-account model, keeping `password_digest` as the source of truth for identity. Thinkroom shows the alternate-login variant (Google OAuth as a second way to authenticate the same `User` row, matched by provider UID) is also a reasonable, well-precedented option — include it as an optional generator flag, not force it on.
5. **Include riffrec-dashboard's operational hardening as defaults**: generic invalid-credentials message (no user-enumeration oracle), an explicitly-owned rate-limit store (not the default `cache_store`, which the code comments show is silently a no-op under Rails' class-body-eval timing), and a documented default of no open self-registration route — make registration opt-in per app rather than assumed.
6. **Do not bundle Devise, multi-tenant `Account`/`AccountUser`, or 2FA by default.** These are real, working patterns (Cora, Lifegarden) but they come from Jumpstart Pro's heavier surface area; compound-stack-rails should keep the default template minimal and let apps that need multi-tenancy or 2FA add it explicitly, following Cora's/Lifegarden's `User::Authenticatable` concern as a documented reference implementation rather than a default.
7. **For local/appliance-style apps with no remote users (Atelier's model — network-authenticated, no `User` table), document that as a legitimate zero-auth mode** rather than forcing a `User`/`Session` model where the actual trust boundary is the network layer (Tailscale ACLs).
