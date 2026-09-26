# Pattern: Stack choices (Gemfile / package.json)

Surveyed: cora, atelier, tada, diskman, lifegarden, thinkroom, riffrec-dashboard, kieranklaassen-com, leva, every, erf-rails, blazer-ai.

## 1. Dominant pattern

Across the seven newest apps (atelier, tada, diskman, thinkroom, riffrec-dashboard, kieranklaassen-com, and cora/lifegarden as the two Hotwire-era holdouts), the current default stack is: **Ruby 3.4.2, Rails 8.1.x, SQLite via `solid_cache`/`solid_queue`/`solid_cable`, Kamal for deploy, `propshaft` for assets, `inertia_rails` (~3.20–3.22) + `vite_rails`/`vite-plugin-ruby` for the frontend, React 19 + TypeScript, Tailwind CSS v4 via `@tailwindcss/vite`, and npm (package-lock.json) as the JS package manager.** `ruby_llm` shows up as the house LLM client in most active projects. Two older/legacy apps (cora, lifegarden, every) predate this convention and instead use Sprockets/esbuild/webpack, Yarn, and Tailwind v3 with a Jumpstart Pro base — they represent the stack *before* the Inertia+Vite convention solidified. Three repos (leva, blazer-ai, erf-rails partially) are Rails **engines/gems**, not standalone apps, and have no package.json or Kamal config at all.

## 2. Per-project breakdown

### cora
- Ruby `3.4.2` (`.ruby-version`), Node `22.11.0` (`.node-version`)
- Gemfile: Rails `~> 8.0` (locked `8.1.3`), Jumpstart Pro base (`eval_gemfile "Gemfile.jumpstart"`), `pg`, `puma ~> 6.0`, `sprockets-rails`/`sassc-rails` (legacy asset pipeline), `turbo-rails ~> 2.0.3`, `stimulus-rails`, `redis`, `solid_queue ~> 1.1` + `mission_control-jobs`, `kamal`, `inertia_rails` (forked, `github: "julik/inertia-rails"`), `inertia_cable ~> 0.2`, `alba`/`typelizer`/`alba-inertia` for typed props, `ruby_llm ~> 1.15` + `ruby_llm-mcp`/`ruby_llm-schema`/house forks `ruby_llm-openclaw`, `ruby_llm-skills`, `blazer`, `blazer-ai` (house gem), `leva ~> 0.3.3` (house gem), `pecorino` (rate limiting), `flipper`/`flipper-ui`, `appsignal`, `sentry` not present (uses appsignal), `ruby_native ~> 0.10.0` + `action_push_native` (house native-app bridge)
- package.json: name `jumpstart-app`, `packageManager: yarn@1.22.22`, JS build via **esbuild** (`esbuild.config.mjs`) + separate `tailwindcss` CLI build (`build:css`), not Vite; React 19, TypeScript 5.9, `@inertiajs/react ^3.0`, Tailwind **v3.4** (not v4), Radix UI, Tiptap, `@ruby-native/react`, `riffrec` (house npm package, pinned via git SHA), `vitest` for JS tests
- Lockfiles: `yarn.lock`. tsconfig.json present.
- `config/deploy.yml` present, `Dockerfile` present, extensive `.github/workflows` (ci.yml, claude-code-review.yml, claude.yml, pr-plan-check.yml, appsignal-bug-monitor.yml, ruby_native_deploy.yml)
- Verdict: most mature/oldest production app; Jumpstart Pro + Hotwire + Inertia hybrid, esbuild not Vite.

### atelier
- Ruby `3.4.2` (`.ruby-version`), no `.node-version`
- Gemfile: Rails `~> 8.1.3`, `puma >= 5.0`, `bootsnap`, no `kamal` gem, no database gem declared (implies SQLite/default or unmanaged), `inertia_rails ~> 3.21`, `vite_rails ~> 3.11`, `bundler-audit` in dev/test
- package.json: `type: module`, `@inertiajs/react ^3.3.1`, React 19, `vite ^8.0.16` + `vite-plugin-ruby ^5.2.2`, Tailwind **v4** via `@tailwindcss/vite`, TypeScript `^5.7.2`, `vitest`, `@base-ui/react`, `shadcn` CLI dep, `riffrec` pulled as a local `.tgz` (`file:vendor/riffrec-1.0.0.tgz`)
- Lockfiles: `package-lock.json` (npm). `tsconfig.json` and `vite.config.ts` present.
- `config/deploy.yml`: **not present**. `Dockerfile`: **not present**. `.github/workflows/ci.yml` only.
- Verdict: Inertia+Vite+React19+TS+Tailwind4 template app, but no Kamal/Docker deploy config checked in yet.

### tada
- Ruby `ruby-3.4.2` (`.ruby-version` with `ruby-` prefix), no `.node-version`
- Gemfile: Rails `~> 8.1.3` (locked `8.1.3.1`), `propshaft`, `sqlite3 >= 2.1`, `importmap-rails` present but unused by frontend (Inertia+Vite used instead), `solid_cache`/`solid_queue`/`solid_cable`, `kamal ~> 2.12.0` (pinned, comment explains shared-host `kamal-proxy` version constraint), `thruster`, `inertia_rails ~> 3.22`, `vite_rails ~> 3.11`, `rails-i18n ~> 8.0`, `mcp` (official Ruby MCP SDK, "cartridge-creator" authoring plane), `ruby_llm ~> 1.16`, `ruby_native ~> 0.11` (house gem)
- package.json: `type: module`, React 19.2.7, TypeScript `^7.0.2` (bleeding-edge major), Tailwind v4, `vite ^8.1.5` + `vite-plugin-ruby`, `three`/`tone`/`zustand`/`gsap`/`perfect-freehand` (creative-coding app), `riffrec` via GitHub SHA pin, custom `script/export_cartridge_registry.mjs` and egress-check scripts wired into `npm run check`
- Lockfiles: `package-lock.json`. `tsconfig.json`, `vite.config.ts` present.
- `config/deploy.yml` and `Dockerfile` present. `.github/workflows/ci.yml` only.

### diskman
- Ruby `3.4.2` (`.ruby-version`), no `.node-version`
- Gemfile: Rails `~> 8.1`, `sqlite3 >= 2.1`, `solid_cache`/`solid_queue`/`solid_cable`, `kamal` (unpinned), `thruster`, `vite_rails ~> 3.10`, `inertia_rails ~> 3.20`, `ruby_llm` (unpinned), `omniauth-spotify`, `async-job-adapter-active_job`/`async-job-processor-redis` (async gem-based job runner instead of solid_queue for some jobs)
- package.json: minimal — `@inertiajs/react ^3.0.2`, `@inertiajs/vite`, React 19.2.4, `@dnd-kit/*` (drag-and-drop), Tailwind v4 via `@tailwindcss/vite`, `vite ^8.0.3` + `vite-plugin-ruby`, **no TypeScript version pinned in deps but `tsconfig.json` exists** and `@types/react` present (implied TS project without explicit `typescript` devDependency — likely relies on a shared/global tsc or an oversight)
- Lockfiles: `package-lock.json`. `tsconfig.json`, `vite.config.ts` present.
- `config/deploy.yml` and `Dockerfile` present. `.github/workflows/ci.yml` only.

### lifegarden
- Ruby `3.4.2` (`.ruby-version`), Node `22` (`.node-version`)
- Gemfile: `ruby File.read(".ruby-version").strip`, Rails `~> 8.1.3` (locked `8.1.3.1`), `sprockets-rails` (legacy pipeline, not propshaft), `pg`, `puma ~> 7.0`, `turbo-rails`/`stimulus-rails` (Hotwire) **alongside** `inertia_rails ~> 3.21.2` (hybrid), `devise ~> 5.0` (only project using Devise directly, others use inertia/native auth), `good_job ~> 4.0` (only project using good_job instead of solid_queue), `cssbundling-rails`/`jsbundling-rails`, `kamal ~> 2.12`, `ruby_llm ~> 1.16.0`
- package.json: `packageManager: yarn@1.22.22`, JS build via **esbuild** (`esbuild.config.mjs`) not Vite, Tailwind **v3.4** via CLI (`build:css` script), React 19.2.7, `@hotwired/turbo-rails`/`@hotwired/stimulus`/`@hotwired/strada` present alongside `@inertiajs/react` (mixed Hotwire/Inertia), `three` for 3D
- Lockfiles: both `bun.lock` and `yarn.lock` present (stale duplicate; `packageManager` field pins yarn). `tsconfig.json` present, no `vite.config.*`.
- `config/deploy.yml` and `Dockerfile` present. `.github/workflows/ci.yml` only.
- Verdict: transitional app — Hotwire assets (esbuild/Tailwind3/Sprockets) plus Inertia bolted on; not the clean Vite pattern.

### thinkroom
- Ruby `3.4.2` (`.ruby-version`), no `.node-version`
- Gemfile: Rails `~> 8.1.3` (locked `8.1.3`), `propshaft`, `sqlite3`, `solid_cable` only (no `solid_cache`/`solid_queue` — app doesn't need background jobs), `kamal ~> 2.12.0` (pinned, comment: match Hetzner shared proxy), `thruster`, `inertia_rails ~> 3.21`, `vite_rails ~> 3.11`, `y-rb ~> 0.7.0` + `y-rb_actioncable ~> 0.1.7` (Yjs realtime collab via solid_cable), `commonmarker ~> 2.8`, `ruby-vips`, `ruby_native ~> 0.10` (house gem), `omniauth-google-oauth2`
- package.json: React 19.2.7, TypeScript `^6.0.3`, Tailwind v4 via `@tailwindcss/vite`, `vite ^8.1.0` + `vite-plugin-ruby`, `@excalidraw/excalidraw`, `@milkdown/*` (rich text editor), `yjs`/`y-prosemirror` (realtime collab), `mermaid`, `shiki`, `riffrec` via GitHub SHA, `playwright` devDependency for E2E, custom `npm run check` running `tsc` on two tsconfigs plus custom node scripts (`export_check.mjs`, `html_document_check.mjs`, `link_check.mjs`)
- Lockfiles: `package-lock.json`. `tsconfig.json`, `vite.config.ts` present.
- `config/deploy.yml` and `Dockerfile` present. `.github/workflows/ci.yml` only.

### riffrec-dashboard
- Ruby `ruby-3.4.2` (`.ruby-version`), no `.node-version`
- Gemfile: Rails `~> 8.1.3` (locked `8.1.3.1`), `propshaft`, `sqlite3`, `kamal ~> 2.12.0` (pinned, same shared-Hetzner-proxy rationale as tada/thinkroom, references a 5-tenant shared host), `thruster`, `image_processing` deliberately commented out with a detailed rationale (KTD0: don't carry infra with no consumer) — variant_processor set explicitly instead, `inertia_rails ~> 3.21`, `vite_rails ~> 3.11`, `solid_queue ~> 1.4` (no `solid_cache`/`solid_cable`), `rack-cors ~> 3.0` scoped to one upload route
- package.json: React 19.2.7, TypeScript `^7.0.2`, Tailwind v4, `vite ^8.1.4` + `vite-plugin-ruby`, `@fontsource-variable/*` fonts, `riffrec` via GitHub SHA, `react-markdown`
- Lockfiles: `package-lock.json`. `tsconfig.json`, `vite.config.ts` present.
- `config/deploy.yml` and `Dockerfile` present. `.github/workflows/ci.yml` only.

### kieranklaassen-com
- Ruby `ruby-3.4.2` (`.ruby-version`), no `.node-version`
- Gemfile: Rails `~> 8.1.3` (locked `8.1.3.1`), `propshaft`, no database gem (static/content site), `kamal ~> 2.12.0`, `thruster`, `inertia_rails ~> 3.21.2` + `vite_rails ~> 3.11` with explicit comment "Connect Rails controllers to React pages without a separate API" / "Build browser and server-rendering bundles with Vite" (SSR build target present: `vite build && vite build --ssr`), `commonmarker ~> 2.8` for markdown posts
- package.json: minimal deps — `@inertiajs/react`, `@inertiajs/vite`, React 19.2.7; TypeScript `^6.0.3`, Tailwind v4, `vite ^8.0.0` + `vite-plugin-ruby`, `vitest`
- Lockfiles: `package-lock.json`. `tsconfig.json`, `vite.config.ts` present.
- `config/deploy.yml` and `Dockerfile` present. `.github/workflows/ci.yml` only.
- Verdict: cleanest/smallest example of the target stack — minimal deps, SSR wired, no extraneous gems.

### leva
- **Not a standalone app — a Rails engine/gem** (`leva.gemspec`, `gemspec` in Gemfile). Ruby `3.3.0` pinned via `.ruby-version` (only project below 3.4).
- Gemfile: `gemspec` + `puma`, `sqlite3`, `sprockets-rails`, `rubocop-rails-omakase`, `annotaterb`; dev-only `git` block pulling a fork of `dspy.rb` (`kieranklaassen/dspy.rb`, branch `feat/ruby-llm-adapter`) with `dspy`/`dspy-ruby_llm`/`dspy-gepa`/`dspy-miprov2`, `opentelemetry-sdk`, `vcr`, `ruby_llm`
- gemspec: `spec.add_dependency "rails", ">= 7.2.0"`; `"liquid", "~> 5.5"`. Locked Rails: `7.2.0`.
- No `package.json`, no `vite.config`, no `tsconfig.json` — pure Ruby gem, no JS.
- No `config/deploy.yml`, no `Dockerfile` (it's a library). `.github/workflows/ci.yml` present.
- This is the "Flexible Evaluation Framework for Language Models in Rails" — an eval/LLM-testing house gem, consumed by cora (`gem "leva", "~> 0.3.3"`).

### every
- Ruby `3.2.2` pinned in Gemfile (`ruby '3.2.2'`), no `.ruby-version` file, no `.node-version`
- Gemfile: Rails `~> 7.1.0` (locked `7.1.5.1`, oldest Rails in the set), `pg`, `puma ~> 5.6`, `dartsass-rails`/`sprockets-rails`/`sassc-embedded` (legacy SCSS pipeline), `jsbundling-rails` with **webpack** (not esbuild/Vite) — `webpack.config.js` + `babel-loader`, `sidekiq ~> 7.3.9` (only project using Sidekiq instead of solid_queue/good_job), `searchkick`/`elasticsearch ~> 7.17`, `stripe`, `doorkeeper` (OAuth provider), `clickhouse-activerecord`, `sentry-ruby`/`sentry-rails`, `tailwindcss-rails ~> 2.0` (Rails-gem-wrapped Tailwind, not npm-driven), `ruby_llm`, `mcp`, `blazer`, `posthog-ruby`
- package.json: no `type: module`, `@rails/actioncable ^6.0.0`/`@rails/ujs` (old Rails UJS-era deps), `quill`/`chartkick`/`moment`/`yjs`+`y-quill`, Jest for JS tests (`jest-environment-jsdom`), build via **webpack** (`webpack --config webpack.config.js`), no React, no Inertia, no TypeScript
- Lockfiles: both `yarn.lock` and `package-lock.json` present (inconsistent). No `tsconfig.json`, no `vite.config`.
- `config/deploy.yml`: **not present**, `Dockerfile`: **not present**, no `.github/workflows` directory at all.
- Verdict: oldest/most legacy app in the set — Rails 7.1, Sidekiq, webpack, Sprockets/dartsass, no Kamal, no CI, no Inertia. Represents the pre-Inertia era.

### erf-rails
- Ruby `4.0.1` (`.ruby-version` — the only project on Ruby 4.x)
- Gemfile: `ruby file: ".ruby-version"`, Rails `~> 8.1.0`, `propshaft`, `pg`, `puma ~> 7.0`, `importmap-rails` + `turbo-rails ~> 2.0.3` + `stimulus-rails` (pure Hotwire, **no Inertia, no Vite, no React** — the one modern app that stays Hotwire-only), `solid_cache`/`solid_queue`/`solid_cable`, `kamal >= 2.0.0.rc2`, `thruster`, `listen ~> 3.9` (file-watching for a dashboard TUI feature, deliberately kept out of dev-only group), `lexxy ~> 0.8.0.beta` (ActionText rich editor), Jumpstart Pro base (`eval_gemfile "Gemfile.jumpstart"`, with `config/jumpstart` load rescue)
- **No `package.json`** — confirmed no JS dependency tree; importmap-rails means zero npm/node build step
- `config/deploy.yml` and `Dockerfile` present. `.github/workflows/ci.yml` only, plus `.devcontainer/` and `.cursor/` present (unique to this repo).
- Verdict: only project combining Rails 8.1 + Kamal + Jumpstart with classic Hotwire/importmap, no JS toolchain at all — a "TUI dashboard" style app, not an Inertia SPA.

### blazer-ai
- **Not a standalone app — a Rails engine/gem** (`blazer-ai.gemspec`, `gemspec` in Gemfile). No `.ruby-version` file; gemspec declares `spec.required_ruby_version = ">= 3.2"`.
- Gemfile: `gemspec` + `puma`, `sqlite3`, `propshaft`, `rubocop-rails-omakase`, `blazer`, `ruby_llm`
- gemspec: `spec.add_dependency "rails", ">= 7.1"`; `"blazer", ">= 3.0"`; `"ruby_llm", ">= 1.0"`. Locked Rails: `8.1.1`.
- No `package.json`, no JS/TS/build tooling at all — pure Ruby engine adding AI-powered NL-to-SQL for Blazer dashboards.
- No `config/deploy.yml`, no `Dockerfile`. `.github/workflows/ci.yml` present.
- Consumed by cora (`gem "blazer-ai"`) and by `every` indirectly via `blazer`.

## 3. Recommendation for compound-stack-rails

- **Ruby 3.4.2**, pinned via `.ruby-version` — the value used by 9 of 10 app-shaped projects (all except every: 3.2.2, leva: 3.3.0, erf-rails: 4.0.1 as outliers). Use `ruby file: ".ruby-version"` in the Gemfile (seen in cora, erf-rails) for single-source-of-truth versioning.
- **Rails `~> 8.1.3`** — the version every project created in the last ~6 months locks to (atelier, tada, diskman, thinkroom, riffrec-dashboard, kieranklaassen-com all resolve to `8.1.3` or `8.1.3.1`).
- **SQLite + `solid_cache`/`solid_queue`/`solid_cable`** as the default persistence/job/cable stack — this is the pattern in tada, diskman, thinkroom (cable only), riffrec-dashboard (queue only), erf-rails; only cora/lifegarden/every still use Postgres+Redis-era stacks from before this convention. Recommend SQLite-first for the starter, matching Rails 8's own default and 4+ of the newest repos.
- **`propshaft`** for asset pipeline (not sprockets) — used by every Rails-8.1 project except cora/lifegarden (legacy sprockets-rails) and erf-rails (also propshaft, confirmed).
- **`inertia_rails` + `vite_rails`/`vite-plugin-ruby` + React 19 + TypeScript** as the frontend stack — this is the unanimous choice across atelier, tada, diskman, thinkroom, riffrec-dashboard, kieranklaassen-com (6/6 of the newest greenfield apps). Version pin around `inertia_rails ~> 3.21` / `vite_rails ~> 3.11` and `vite ^8.x` on the JS side.
- **Tailwind CSS v4 via `@tailwindcss/vite`** (not the v3 CLI/PostCSS pipeline) — used by all 6 Vite-based apps; only the two esbuild-era apps (cora, lifegarden) are still on Tailwind v3.
- **npm with `package-lock.json`** as the JS package manager — 6 of 8 JS-having projects use npm; only cora and lifegarden use Yarn (both legacy esbuild apps), and every has both lockfiles inconsistently. Recommend npm for the starter to match the dominant/newer convention.
- **`kamal ~> 2.12.0` pinned** (not left floating) with `config/deploy.yml` + `Dockerfile` + `thruster` — the pattern in tada, thinkroom, riffrec-dashboard, kieranklaassen-com, all with the same comment rationale about matching a shared `kamal-proxy` minimum version. Recommend the starter pin Kamal explicitly rather than leaving it unbounded, and ship `thruster` for HTTP asset acceleration.
- **House gems to make first-class/optional add-ons**: `ruby_llm` (LLM client, in 8/12 projects), `ruby_native` (native-app bridge, cora/tada/thinkroom), `alba` + `typelizer` + `alba-inertia` (typed Inertia props, cora) — worth documenting as the "add AI" and "add typed props" opt-in paths rather than baking into the starter Gemfile.
- **TypeScript strictness**: every Vite-based app ships a `tsconfig.json` and either a `check`/`typecheck` npm script (`tsc -p tsconfig.app.json && tsc -p tsconfig.node.json`, or `tsc --noEmit`) — the starter should ship this split-tsconfig + `npm run check` convention from day one (seen consistently in thinkroom, tada, riffrec-dashboard, kieranklaassen-com).
- **CI**: every active app-shaped repo has a `.github/workflows/ci.yml`; only `every` (the oldest/legacy app) has none. The starter should ship a CI workflow by default.
