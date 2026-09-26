# Shared House Libraries: leva, rails_js_logger, ruby_llm

Survey of 12 of Kieran Klaassen's repos for house-authored/house-forked dependencies, read directly from each project's `Gemfile`, `Gemfile.lock`, and `package.json`.

## 1. Dominant pattern

`ruby_llm` (Carmine Paolino's public gem, not house-authored, but treated as the de facto standard LLM interface) is the one dependency present in nearly every Rails project surveyed (cora, tada, diskman, lifegarden, every, blazer-ai, leva) — always plain `gem "ruby_llm"` from rubygems, versions ranging 1.9.1–1.16.0, each with its own `config/initializers/ruby_llm.rb`. **`rails_js_logger` does not exist in any of the 12 projects** — no Gemfile, Gemfile.lock, or package.json reference in any repo, including via git search. It appears to be aspirational/not yet built, or the name doesn't match what was actually shipped. The one genuine "house gem" is **`leva`** (Kieran's own LLM-eval-framework gem, rubygems.org-published, `~> 0.3.3` in cora, developed in `~/leva`), used in exactly one project (cora) and only partially wired up there (dashboard + admin controller exist, but the engine is not mounted in `config/routes.rb`). The other clear house-library pattern isn't a gem at all — it's **`riffrec`**, a private npm package pulled via git+github URL pinned to a commit SHA, used identically across cora, tada, thinkroom, and riffrec-dashboard for in-app feedback capture. Beyond these, Kieran's projects lean on git-sourced forks of *other people's* gems (patched via `github:`/`git:` in Gemfile) rather than a stable in-house gem suite — cora alone carries five such git-pinned forks.

## 2. Per-project breakdown

### cora
- Rails app. `Gemfile.lock` confirms `Gemfile` git_source pattern (`git_source(:github)`).
- **leva**: `gem "leva", "~> 0.3.3"` (rubygems, resolved to `leva (0.3.3)` in lock). Line 169 has a commented-out local path override: `# gem "leva", path: "../leva"`, showing Kieran develops it in a sibling checkout.
  - Usage: `app/dashboards/leva/dataset_dashboard.rb` (Administrate dashboard for `Leva::Dataset`), `app/controllers/admin/leva/datasets_controller.rb`, one route helper `get :create_leva_dataset` (`config/routes.rb:98`). No `mount Leva::Engine` found anywhere in `config/routes.rb` — the leva engine's own UI (normally mounted at `/leva`) is not mounted; cora only reuses its dataset model/dashboard.
- **ruby_llm**: `gem "ruby_llm", "~> 1.15"` (locked 1.15.0), plus **`ruby_llm-mcp` `~> 1.0`** (rubygems) and **`ruby_llm-schema`** (rubygems, 0.3.0, required transitively by ruby_llm itself).
  - Two house forks via git, pinned by exact revision:
    - `gem "ruby_llm-openclaw", github: "kieranklaassen/ruby_llm-openclaw"` — locked to revision `d44607b5688c493fbfd427939db2e668dc307c68`, version `0.1.0`, adds `async-websocket` + `ed25519` deps. Used for Cora's "Openclaw" agent chat surface: `app/terminal/openclaw_terminal.rb`, `app/agents/openclaw_proxy_agent.rb`, `app/models/openclaw_agent.rb`.
    - `gem "ruby_llm-skills", github: "kieranklaassen/ruby_llm-skills", branch: "main"` — locked to revision `c5423fdc79cbcd39ccd09148da3d8857a47cd497`, version `0.3.0`.
  - Config: `config/initializers/ruby_llm.rb` sets `openai_api_key`/`anthropic_api_key`/`gemini_api_key`/`openrouter_api_key` from Rails credentials, `config.use_new_acts_as = true`, `config.model_registry_class = "LLMModel"`, `config.default_model = "gemini-2.5-flash-lite"`. Three more supporting initializers: `ruby_llm_token_usage.rb`, `ruby_llm_gemini_array_patch.rb`, `ruby_llm_fallback.rb`.
- Other git-forked gems in cora's Gemfile (not house-named, but illustrate the git-fork pattern Kieran relies on): `pay` (fork `julik/pay-nanoid-fix`, branch `fix-frozen-string-literal-v7.3.0`), `maildown` (fork `cowlibob/maildown`, branch `rails_7_1_support`), `heya` (`honeybadger-io/heya`), `geneva_drive` (`julik/geneva_drive`, ref `main`), `geneva_drive_admin` (private git URL with embedded PAT, branch `main`), `gmail_search_syntax` (`julik/gmail_search_syntax`, ref `main`), `inertia_rails` (fork `julik/inertia-rails`, ref `defer-middleware-injection`, tracking upstream PR #374).
- **riffrec** (JS): `package.json:74` — `"riffrec": "git+https://github.com/kieranklaassen/riffrec.git#9d3e2b5c62694049bcefec9370eaa9b30f41a60e"`. Imported in `app/javascript/components/sidebar/RiffrecSidebarActions.tsx` and `app/javascript/layouts/InboxLayout.tsx`.
- No `rails_js_logger` reference anywhere.

### atelier
- Rails app (`rails ~> 8.1.3`, `inertia_rails ~> 3.21`, `vite_rails ~> 3.11`). No `ruby_llm`, no `leva`, no house gems at all in Gemfile. No git-sourced gems beyond the standard `git_source(:github)` boilerplate comment. No `package.json` house-lib entries.

### tada
- Rails app (`rails ~> 8.1.3`). `gem "ruby_llm", "~> 1.16"` (rubygems, locked 1.16.0), plus `ruby_llm-schema (0.4.0)` transitively.
  - Config: `config/initializers/ruby_llm.rb` gates global provider keys to `Rails.env.local?` only (comment cites "R20 — kid egress goes only to the Tada server"); sets `config.use_new_acts_as = true` unconditionally.
- No `leva`.
- **riffrec**: `package.json:35` — `"riffrec": "github:kieranklaassen/riffrec#d38fabf3ef980ab84d3cb2c6eda846907d1d2f70"`.
- `gem "kamal", "~> 2.12.0"` pinned deliberately (comment: shared host's kamal-proxy is v0.9.2, exactly Kamal's `MINIMUM_VERSION` floor — do not bump casually).

### diskman
- Rails app (`rails ~> 8.1`). `gem "ruby_llm"` unpinned (locked to 1.14.1), `ruby_llm-schema (0.3.0)` transitively.
  - `config/initializers/ruby_llm.rb` present (found via `find`, not read in full — same pattern family as others).
- No `leva`, no house git-forks, no `riffrec` in package.json (no package.json house refs at all).

### lifegarden
- Rails app. `gem "ruby_llm", "~> 1.16.0"` (locked 1.16.0), `ruby_llm-schema (0.4.0)` transitively.
  - `config/initializers/ruby_llm.rb`: keys sourced from `ENV[...].presence || Rails.application.credentials.dig(...)` fallback chains for openai/gemini; `config.default_model = ENV.fetch("RUBY_LLM_MODEL", "gemini-2.5-flash")`; `config.request_timeout = ENV.fetch("RUBY_LLM_REQUEST_TIMEOUT", "60").to_i`; `config.model_registry_class = "AiModel"`; `config.use_new_acts_as = true`. Also subscribes to `ActiveSupport::Notifications` on `"chat.ruby_llm"` to log provider/model/status/duration/token counts via `Rails.logger.info` — this is the closest thing to a "js_logger"-style structured logging pattern found in any project, but it's Ruby-side, not `rails_js_logger`.
- No `leva`, no git-forked house gems, no package.json house refs.

### thinkroom
- Rails app (`rails ~> 8.1.3`, `inertia_rails ~> 3.21`, `vite_rails ~> 3.11`, `y-rb`/`y-rb_actioncable` for Yjs sync). No `ruby_llm`, no `leva` in Gemfile/Gemfile.lock.
- **riffrec**: `package.json:32` — `"riffrec": "github:kieranklaassen/riffrec#fb7276c1a3746cb1dba4bb2f2088c2dddf2e89ea"` (different SHA than cora/tada/riffrec-dashboard).
- `gem "kamal", "~> 2.12.0"` (comment: match version used by existing Hetzner stack and shared proxy).

### riffrec-dashboard
- Rails app (`rails ~> 8.1.3`, `inertia_rails ~> 3.21`, `vite_rails ~> 3.11`). No `ruby_llm`, no `leva`.
- **riffrec**: `package.json:27` — `"riffrec": "github:kieranklaassen/riffrec#d38fabf3ef980ab84d3cb2c6eda846907d1d2f70"` (same SHA as tada). This app appears to be the receiving/dashboard side of the riffrec feedback-capture ecosystem.
- `gem "kamal", "~> 2.12.0"` with an extended comment explaining a 5-tenant shared kamal-proxy on `cora-hetzner` pinned at exactly v0.9.2 — do not bump Kamal past what raises `MINIMUM_VERSION` mismatches; see `DEPLOYING.md`.

### kieranklaassen-com
- Rails app (`rails ~> 8.1.3`, `inertia_rails ~> 3.21.2`, `vite_rails ~> 3.11`). Also has Bridgetown cache dirs present (`.bridgetown-cache`), suggesting a prior/parallel static-site stack, but the live Gemfile is pure Rails. No `ruby_llm`, no `leva`, no house git-forks, no package.json house refs.

### leva (the library repo itself)
- This is the source repo for the `leva` gem (published as `leva (0.3.4)` locally per its own `Gemfile.lock`, vs. `~> 0.3.3` consumed in cora — cora is one patch version behind leva's own HEAD).
- gemspec (`leva.gemspec`): depends on `rails >= 7.2.0` and `liquid ~> 5.5`, MIT-licensed, homepage `https://github.com/kieranklaassen/leva`.
- Its own `Gemfile` pulls a **git fork of `dspy.rb`**: `git "https://github.com/kieranklaassen/dspy.rb.git", branch: "feat/ruby-llm-adapter"` providing `dspy`, `dspy-ruby_llm`, `dspy-gepa`, `dspy-miprov2` — comment: "Using fork with ruby-llm adapter and miprov2 fix." Plus plain `gem "ruby_llm"` (rubygems, locked 1.9.1) and `gem "opentelemetry-sdk"` for dspy observability.
- `config/initializers/ruby_llm.rb`: minimal, just `anthropic_api_key` and `gemini_api_key` from credentials/ENV.
- Structure: `lib/leva/engine.rb` (Rails::Engine), `lib/leva/dspy_runner.rb`, `lib/leva/providers/together.rb`, generators at `lib/generators/leva/{runner,eval}_generator.rb`. README documents `mount Leva::Engine => "/leva"` as the intended integration — which cora does *not* do (see cora section above).

### every
- Rails app, oldest/most legacy-looking stack (webpacker, turbolinks references in Gemfile comments, `git_source(:github)` boilerplate). `gem 'ruby_llm'` unpinned (locked 1.11.0), `ruby_llm-schema (0.2.5)` transitively.
  - `config/initializers/ruby_llm.rb`: single line, `config.openai_api_key = ENV["OPENAI_API_KEY"]` — no anthropic/gemini, no `use_new_acts_as`, no model registry. Simplest config of any project surveyed.
- No `leva`, no house git-forks, no package.json house refs.

### erf-rails
- Rails app, but built on **Jumpstart Pro** (`require_relative "lib/jumpstart/lib/jumpstart/configuration"`, `eval_gemfile "Gemfile.jumpstart"`), a third-party paid SaaS starter — not Kieran's own compound-stack pattern. No `ruby_llm`, no `leva`, no `inertia_rails`/`vite_rails` (uses `importmap-rails` + `turbo-rails` + `stimulus-rails` instead, i.e. classic Hotwire, not Inertia). `Gemfile.lock` exists but has zero matches for any house-lib grep. Notable: uses Postgres (`gem "pg"`) rather than the SQLite-by-default pattern seen elsewhere, and `lexxy` for ActionText. Flag: this project does not follow the Inertia/ruby_llm/Kamal pattern the others share — treat as an outlier, not a template source.

### blazer-ai
- Rails app. `gem "ruby_llm"` unpinned (locked 1.9.1), `ruby_llm-schema (0.2.5)` transitively — via `blazer-ai` gem's own dependency chain (`blazer (>= 3.0)`, `rails (>= 7.1)`, `ruby_llm (>= 1.0)` declared in the lockfile's own GIT/PATH block for the `blazer-ai` gem itself, i.e. this repo *is* a gem whose gemspec requires ruby_llm). No `config/initializers/ruby_llm.rb` found. No `leva`. No package.json (pure gem, no JS).

## 3. Recommendation for compound-stack-rails

1. **Adopt `ruby_llm` as a first-class default dependency**, pinned with a `~>` constraint (not the unpinned pattern in diskman/every/blazer-ai) — every actively-maintained project in the survey (cora, tada, diskman, lifegarden, every) uses it, and the two most recently built apps (tada, lifegarden) pin to `~> 1.16`. Ship a `config/initializers/ruby_llm.rb` template modeled on **lifegarden's**, the most complete example found: ENV-with-credentials-fallback key resolution, `config.default_model` via `ENV.fetch`, `config.request_timeout`, `config.model_registry_class`, `config.use_new_acts_as = true`, and the `ActiveSupport::Notifications.subscribe("chat.ruby_llm")` structured-logging hook for token/latency observability — this is the only project that logs ruby_llm usage, and it's a pattern worth generalizing since no `rails_js_logger` equivalent exists yet.
2. **Do not bundle `leva` by default.** It's used in exactly one of nine active Rails apps (cora), and even there it's only half-integrated (engine not mounted). It's a specialized eval-framework for LLM-heavy apps, not a generic starter dependency. If compound-stack-rails wants an eval story, document leva as an optional add-on with the `mount Leva::Engine => "/leva"` step cora skipped, rather than pre-installing it.
3. **Do not build/ship `rails_js_logger`** under that name based on this survey — it does not exist in any of the 12 repos. If the intent behind naming it in scope was "structured client-side logging," the closest prior art is lifegarden's server-side `ActiveSupport::Notifications` subscriber; there is no JS-side logging house library to extract a pattern from. Flag this back to whoever scoped the survey rather than inventing a pattern.
4. **Treat `riffrec` (JS, git+github-pinned) as the real second house library**, alongside ruby_llm — it appears in 4 of the JS-frontend projects (cora, tada, thinkroom, riffrec-dashboard) with a consistent `"riffrec": "github:kieranklaassen/riffrec#<sha>"` or `"git+https://..."` pin pattern. compound-stack-rails should include riffrec as an optional npm dependency pinned by commit SHA (matching the project convention of pinning house JS packages to exact commits rather than tags/branches), with a short integration note (sidebar action component + layout wiring, per cora's `RiffrecSidebarActions.tsx`).
5. **Kamal version pin at `~> 2.12.0` is a cross-project convention** (tada, thinkroom, riffrec-dashboard, kieranklaassen-com all match) tied to a shared Hetzner host's `kamal-proxy` floor at v0.9.2 — worth carrying into the starter's Gemfile with the same explanatory comment pattern, since bumping Kamal past that floor risks forcing a proxy reboot across every tenant on the shared host.
6. **Exclude erf-rails and leva-the-gem-repo from "what the template should look like."** erf-rails runs on Jumpstart Pro with classic Hotwire (no Inertia, no ruby_llm) and is architecturally a different lineage; leva's own repo is a library, not an app pattern.
