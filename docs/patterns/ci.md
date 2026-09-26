# CI Configuration Patterns

## Summary

Every Rails project in the survey uses GitHub Actions, with a near-identical three-job skeleton: `scan_ruby` (brakeman + bundler-audit), `lint` (rubocop or standardrb, sometimes with a `RUBOCOP_CACHE_ROOT` cache keyed on `.ruby-version`/`.rubocop.yml`/`Gemfile.lock`), and `test` (Postgres or SQLite, `bin/rails db:test:prepare test`). Ruby setup is almost always `ruby/setup-ruby@v1` with `bundler-cache: true` (GitHub-managed gem caching) rather than manual caching. Node/JS projects add `actions/setup-node` with `cache: npm` or `cache: yarn`, plus a `npm run check`/`typecheck` step and occasionally `npm audit`. All workflows trigger on `pull_request` + `push: [main]`. Only one project (`cora`) departs from this baseline: it runs entirely on self-hosted Hetzner runners (`runs-on: [self-hosted, hetzner]`) with hand-rolled Postgres/Redis bootstrapping, `flock`-guarded shared caches, and no `actions/cache` or GitHub-hosted `setup-ruby` caching at all — a scale/cost optimization, not a template default. No project uses a language/version matrix. None run bundler-audit and brakeman via reusable/composite actions; each repo duplicates the steps inline.

## Per-project breakdown

### cora
- File: `.github/workflows/ci.yml` (22.5KB), plus separate `appsignal-bug-monitor.yml`, `claude-code-review.yml`, `claude.yml`, `pr-plan-check.yml`, `ruby_native_deploy.yml` in the same dir.
- Trigger: `pull_request: branches: ["*"]`, `push: branches: [main]`. Has `concurrency: group: ci-${{ github.ref }}, cancel-in-progress: true`.
- Runner: **self-hosted** — `runs-on: [self-hosted, hetzner]` for every job (4 runners share one Hetzner box, per comments).
- Jobs: `scan` (brakeman only, no bundler-audit), `lint` (`standardrb`, `erb_lint --lint-all`, `bin/rails zeitwerk:check`), `js_test` (`yarn typecheck`, `yarn test`), `test` (Minitest, `PARALLEL_WORKERS: 15`), `system_test` (`bin/rails test:system`, `PARALLEL_WORKERS: 1`, uploads screenshots on failure via `actions/upload-artifact@v7`), `production-boot-check` (needs all above; verifies prod-only gem boot, catches gems missing from prod group).
- Caching: none of GitHub's `actions/cache` or `bundler-cache: true`. Gems pre-installed at `/opt/cora-bundle` (`BUNDLE_PATH`) on the runner; `bundle install` just verifies presence. Custom `~/cora-runner-cache/` holds `node_modules` (rsync + flock, keyed on `yarn.lock` hash) and Bootsnap cache (keyed on Ruby version + `Gemfile.lock` hash). Postgres uses a per-schema-hash **template database** (`cora_test_template_<sha>`) cloned via `createdb --template` to skip `db:test:prepare` on warm runs.
- Concurrency safety: `flock` around `bundle install`, apt installs, and DB template creation since 4 runners share one Postgres/Redis instance; DB names are runner+run-id scoped.
- No matrix builds. Node version via `.node-version` file (`actions/setup-node@v5`, `package-manager-cache: false` — caching is custom, not the action's).

### atelier
- File: `.github/workflows/ci.yml` (489 bytes) — single job.
- Trigger: `pull_request`, `push: [main]`, plus `workflow_dispatch`.
- Runner: `macos-14` (not ubuntu — only project doing this).
- Single `test` job: `ruby/setup-ruby@v1` (ruby 3.4.2, `bundler-cache: true`), `actions/setup-node@v4` (node 22, `cache: npm`), `npm ci`, `npm run typecheck`, `npm run test:frontend`, `bin/rails test`.
- No brakeman, no bundler-audit, no rubocop/standardrb, no separate lint job. Simplest CI in the set.

### tada
- File: `.github/workflows/ci.yml` (5.2KB).
- Trigger: `pull_request`, `push: [main]`.
- Jobs: `scan_ruby` (brakeman + `bin/bundler-audit`), `check_js` (`actions/setup-node@v4` node 22 cache npm, `npm run check`, `npm audit --audit-level=high`), `lint` (rubocop with `actions/cache@v4` keyed on `.ruby-version`+`.rubocop.yml`+`.rubocop_todo.yml`+`Gemfile.lock`, cache key includes `github.run_id` on default branch for cache-busting), `egress_browser` (Playwright/Chromium browser test asserting no requests leave the app's own origin — built assets, `RAILS_ENV: production`, boots server, custom `script/egress_browser_check.mjs`), `test` (prebuilds Vite test assets, `bin/rails db:test:prepare test`).
- Uses `bin/vite build` explicitly before tests to avoid Minitest parallel workers racing Vite's autoBuild.
- No Postgres/Redis service containers visible in `test` (likely SQLite).

### diskman
- File: `.github/workflows/ci.yml` (1.9KB).
- Trigger: `pull_request`, `push: [main]`.
- Jobs: `scan_ruby` (brakeman + bundler-audit), `lint` (`npx tsc --noEmit`, `npx vite build` — no rubocop/standardrb here), `test` (npm ci, vite build in test env, `bin/rails db:prepare`, `bin/rails test`), `production_db_prepare` (dedicated job asserting SQLite multi-db files exist: `storage/databases/production{,_cache,_queue,_cable}.sqlite3` — catches Solid Queue/Cache/Cable config regressions).
- All `runs-on: ubuntu-latest`, no matrix, no caching beyond `bundler-cache: true`.
- Uses a dummy 64-char `SECRET_KEY_BASE` for the production DB-prepare job.

### lifegarden
- File: `.github/workflows/ci.yml` (2.1KB).
- Trigger: `pull_request`, `push: [main]`.
- Jobs: `scan` (brakeman + `bundler-audit check --update`), `lint` (standardrb + erb_lint), `test` (Postgres 15-bookworm service container, `libvips`+`postgresql-client` apt install, yarn with `cache: yarn` keyed on `.node-version`, `yarn build:css && yarn build`, `yarn typecheck && yarn test:js`, then `bin/rails db:test:prepare test`), `docker` (builds production image: `docker build --tag lifegarden:${{ github.sha }} .` — no push, just a build-validity check).
- Only project with an explicit `docker build` validation job (no registry push).

### thinkroom
- File: `.github/workflows/ci.yml` (5.8KB).
- Trigger: `pull_request`, `push: [main]`.
- **All actions pinned to commit SHA** with version comment (e.g. `actions/checkout@9c091bb2...# v7.0.0`) — only project doing this, explicitly for supply-chain safety per an inline comment ("a compromised or retagged upstream action cannot silently change what runs here").
- Jobs: `scan_ruby` (brakeman + bundler-audit), `lint` (rubocop, same cache pattern as tada), `test` (npm check, `bin/vite build --mode test`, `bin/rails db:test:prepare test`), `scan_javascript` (`npm audit --omit=dev --audit-level=moderate`), `browser_checks` (Playwright: boots `bin/vite dev` + `bin/rails server`, warms Vite module graph, then runs ~9 custom regression scripts like `sync_check.mjs`, `link_check.mjs`, `mermaid_check.mjs`).
- No Postgres/Redis service block (commented out, suggesting SQLite/no DB dependency in test).

### riffrec-dashboard
- File: `.github/workflows/ci.yml` (4.1KB).
- Trigger: `pull_request`, `push: [main]`.
- Same SHA-pinned actions style as thinkroom, explicit comment: "Pins mirror thinkroom's." Also explicitly states there is **no deploy job** — deploys are manual/operator-driven, gated on DNS + a stop/go checklist (shared Hetzner host/kamal-proxy with four other tenants).
- Jobs: `scan_ruby` (brakeman + bundler-audit), `scan_javascript` (npm audit, "JS counterpart to scan_ruby's bundler-audit"), `lint` (rubocop with cache), `test` (npm check, `bin/vite build --mode test`, `bin/rails db:test:prepare test`).
- No libvips install (comment notes image_processing/ruby-vips not in Gemfile currently).

### kieranklaassen-com
- File: `.github/workflows/ci.yml` (2.0KB).
- Trigger: `pull_request`, `push: [main]`.
- Jobs: `scan_ruby` (brakeman + bundler-audit), `lint` (rubocop **and** `npm run check` **and** `npm run test:frontend` combined into one job, `actions/setup-node@v6`), `test` (builds browser+SSR assets via `npm run build`, starts Inertia SSR server as background process with a health-check polling loop against `/health` on port 13714, runs `bin/rails test` with `INERTIA_SSR_URL` + `SSR_STRICT: "1"`, dumps SSR log on failure), `container` (`docker build --tag kieranklaassen-com:test .`).
- Only project exercising Inertia **SSR** explicitly in CI.

### leva
- File: `.github/workflows/ci.yml` (1.4KB) — smallest full workflow.
- Trigger: `pull_request`, `push: [main]`.
- Jobs: `lint` (rubocop only, `ruby-version-file: .ruby-version`), `test` (`bin/rails test`, installs `google-chrome-stable`, `libjemalloc2`, `libsqlite3-0`, `libvips` via apt — suggests SQLite + system-test/Capybara+Chrome usage, uploads failure screenshots via `actions/upload-artifact@v4`).
- No brakeman, no bundler-audit, no JS/typecheck step at all (Redis service block present but commented out).

### erf-rails
- File: `.github/workflows/ci.yml` (4.4KB). This is a "Jumpstart Pro Rails" template project (per README), not a from-scratch app.
- Trigger: `pull_request`, `push: [main]`.
- Jobs: `scan_ruby` (brakeman + bundler-audit), `scan_js` (`bin/importmap audit` — only project using Importmap instead of a JS bundler/npm), `lint` (rubocop with `actions/cache@v5` + `erb_lint --lint-all`), `test` (Postgres `latest` + Redis service containers, `bin/rails db:test:prepare zeitwerk:check test`), `system-test` (separate job, `test:system`, same services, uploads screenshots on failure via `actions/upload-artifact@v7`).
- Only project running `zeitwerk:check` inline as part of the `test` task rather than a dedicated step (cora runs it as a separate lint step).

### blazer-ai
- File: `.github/workflows/ci.yml` (733 bytes) — smallest of all.
- Trigger: `pull_request`, `push: [main]`.
- Jobs: `lint` (rubocop, pinned `ruby-version: 3.2.2`), `test` (`bundle exec rake test`, same pinned Ruby version).
- No brakeman, no bundler-audit, no JS/frontend step, no services. Looks like an early-stage or minimal-scope project.

### every
- **No `.github/workflows` directory** — CI config not present. Confirmed Rails app (Gemfile, `app/` present, `ruby '3.2.2'`), but has `app.json` (Heroku-style), `Aptfile`, `docker-compose.*.yml` files instead — suggests Heroku-based deploy without GitHub Actions CI, or CI configured elsewhere (not found on disk).

## Recommendation for compound-stack-rails

1. **Adopt the ubiquitous 3-job GitHub Actions skeleton** as the default: `scan_ruby` (brakeman + bundler-audit), `lint` (rubocop with the cache pattern below), `test` (service containers + `bin/rails db:test:prepare test`). This is the pattern in 8 of 11 projects with CI (tada, diskman, lifegarden, thinkroom, riffrec-dashboard, kieranklaassen-com, erf-rails, and a subset in cora/atelier). Trigger on `pull_request` + `push: [main]`, matching every project surveyed.

2. **Use `ruby/setup-ruby@v1` with `bundler-cache: true`** for gem caching (universal across all non-cora projects) rather than manual `actions/cache` for gems — it's the de facto standard here. Reserve cora's self-hosted/flock/template-DB approach as an opt-in "scale" variant documented separately, not the default — it's justified there by 4 runners sharing one Hetzner host, which won't apply to a fresh starter repo.

3. **Add the rubocop cache block** verbatim from tada/thinkroom/riffrec-dashboard/erf-rails: `actions/cache` on `tmp/rubocop`, keyed on `hashFiles('.ruby-version', '**/.rubocop.yml', '**/.rubocop_todo.yml', 'Gemfile.lock')`, with the `github.run_id` cache-busting trick on the default branch. This exact block appears near-verbatim in 4 projects.

4. **Add a JS/TS job** (`actions/setup-node` with `cache: npm`, `npm ci`, `npm run check`/`typecheck`) since compound-stack-rails is Inertia-based — every Inertia project in the survey (tada, diskman, thinkroom, riffrec-dashboard, kieranklaassen-com) has this. Follow riffrec-dashboard's `scan_javascript` job (`npm audit --omit=dev --audit-level=moderate`) as the JS-dependency-audit counterpart to bundler-audit.

5. **Pin GitHub Actions to commit SHAs** (thinkroom, riffrec-dashboard pattern) rather than floating tags — both projects adopted this deliberately for supply-chain safety and it's a low-cost hardening step worth carrying into a starter template.

6. **Include a Vite pre-build step before tests** (`bin/vite build --mode test` / `RAILS_ENV=test bin/vite build`) as seen in tada, riffrec-dashboard, thinkroom — avoids Minitest parallel workers racing Vite's on-demand autoBuild, a real flakiness source these projects specifically worked around.

7. **Skip system-test/browser-check jobs by default** but document them as an add-on: only cora, erf-rails, leva, and thinkroom run system/browser tests in CI, and thinkroom/tada's Playwright egress-check jobs are app-specific rather than generalizable. A starter template should ship the Minitest/RSpec unit-test job and leave Capybara/Playwright system tests as an opt-in job template, since roughly half the surveyed projects skip them entirely.

8. **Do not add a matrix build** — zero projects in this survey use one (single Ruby/Node version each), so there's no house convention to follow there.

9. **Optional `docker build` validation job** (no push) — seen in lifegarden and kieranklaassen-com — is a cheap sanity check worth including given compound-stack-rails targets Kamal (which builds/pushes the same Dockerfile); it catches Dockerfile breakage before a deploy attempt.
