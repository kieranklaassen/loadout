# Testing Setup — Pattern Survey

Surveyed: cora, atelier, tada, diskman, lifegarden, thinkroom, riffrec-dashboard, kieranklaassen-com, leva, every, erf-rails, blazer-ai.

## Summary

The dominant pattern across Kieran's newer projects (everything except `every`) is **Rails `Minitest` + fixtures + parallel workers**, with no FactoryBot anywhere except the one legacy RSpec app. System/browser tests use **Capybara driven by Selenium `headless_chrome`** (never Cuprite). The five Inertia apps (diskman, lifegarden, thinkroom, riffrec-dashboard, kieranklaassen-com, tada) all `require "inertia_rails/minitest"` for `assert_inertia_*` helpers, though tada additionally hand-rolls its own `inertia_props` parser instead of relying on the gem helper. Frontend JS testing is **Vitest + `@testing-library/react` + jsdom**, run via `npm run test`/`test:frontend`, wired into CI alongside `bin/rails test`. Two projects (tada, thinkroom) layer real-browser **Playwright** checks in CI for egress/regression smoke testing, run as plain Node scripts rather than a Playwright test-runner suite. `VCR` + `WebMock` shows up in the four projects that talk to real external/LLM APIs (cora, diskman, leva, erf-rails uses WebMock only). Coverage tooling (SimpleCov) is present in exactly one project (cora) and is commented out/unused. `every` is the outlier: an older, pre-Inertia Rails app on RSpec + FactoryBot + Capybara `features/` specs + Jest/webpacker, mid-migration toward a `test/` Minitest suite (109 rspec specs vs. 26 minitest tests).

## Per-project breakdown

### cora
- Framework: Minitest (`test/` — `agents`, `campaigns`, `chats`, `evals`, etc.). No `spec/`.
- Fixtures: `fixtures :all` in `test/test_helper.rb`; 46 fixture YAML files in `test/fixtures/`.
- System tests: Capybara + Selenium `headless_chrome` in `test/application_system_test_case.rb`, screen_size `[1400,1400]`, supports a remote Selenium grid via `CAPYBARA_SERVER_PORT`/`SELENIUM_HOST` env vars (containerized CI). VCR is explicitly turned off during system tests (`VCR.turn_off!`) to allow real browser network.
- VCR/WebMock: heavy use — `test/test_helper.rb` configures VCR with `hook_into :webmock`, cassette dir `test/vcr_cassettes`, and ~10 `filter_sensitive_data` scrubbers for Anthropic/OpenAI/Google/OpenRouter/Every/Slack/Linq/Monologue API keys, plus header-level scrubbing for `X-API-Key`/`Authorization: Bearer ...`. `WebMock.disable_net_connect!` allows only localhost + `chromedriver.storage.googleapis.com` + `rails-app` + `selenium`.
- Parallelism: `parallelize(workers: [Etc.nprocessors, 15].min)`, capped at 15 because each worker gets its own Redis DB (1–15).
- Coverage: `gem "simplecov"` in Gemfile but `require "simplecov"` / `SimpleCov.start` are commented out in `test/test_helper.rb` — installed, not active.
- Frontend: Vitest (`vitest.config.ts`), `environment: "jsdom"`, setup file `app/javascript/test/setup.ts`, plugin `@vitejs/plugin-react`, includes `app/javascript/**/*.{test,spec}.{ts,tsx}`, TZ pinned to `America/Los_Angeles` for deterministic date tests. `@testing-library/{dom,jest-dom,react,user-event}` in package.json. `npm run test` → `vitest run`.
- CI (`ci.yml`): `bin/rails test --profile=20` then `bin/rails test:system` as separate steps.

### atelier
- Framework: Minitest (`test/` — `controllers`, `helpers`, `integration`, `services`, `support`). No `spec/`.
- Fixtures: dir present but empty (0 `.yml` files found) — fixtures infra exists, not populated.
- System tests: none (`no application_system_test_case.rb`, no Capybara/Selenium in Gemfile).
- `test/test_helper.rb`: hermetic test isolation via `ERF_ROOT`/`TUIN_ROOT` env vars pointed at `tmp/erf-test-root`/`tmp/tuin-test-root` so tests never touch the developer's real `~/erf`/`~/tuin`. `parallelize(workers: 1)` deliberately — comment explains controller tests share hermetic state-tree and would race under real parallelism.
- VCR/WebMock: not present in Gemfile.
- Frontend: Vitest (`test:frontend": "vitest run app/frontend"`), no RTL/jsdom deps listed in package.json grep.
- CI: `npm run test:frontend` then `bin/rails test`.

### tada
- Framework: Minitest (`test/` — `controllers`, `mcp`, `mailers`, plus root-level tests like `deploy_config_test.rb`, `native_config_test.rb`, `production_data_plane_test.rb`, `i18n_test.rb`). No `spec/`.
- Fixtures: `fixtures :all`; 22 fixture files.
- System tests: no `application_system_test_case.rb`; no Capybara/Selenium in Gemfile.
- Inertia testing: custom `test/test_helpers/inertia_test_helper.rb` defines its own `inertia_props` by regex-parsing the `<script data-page="app" type="application/json">` tag and `JSON.parse`-ing it, included via `ActiveSupport.on_load(:action_dispatch_integration_test)` — does **not** use `inertia_rails/minitest`'s `assert_inertia_props`.
- `test/test_helper.rb` also requires bespoke helpers: `session_test_helper`, `env_test_helper`, `rails_env_test_helper`, `chat_test_helper`, `fake_provider_response_helper`, `fake_github_helper`.
- Parallelism: `parallelize(workers: :number_of_processors)`; `Rails.cache.clear` in setup to reset rate-limit counters between tests.
- Frontend: Vitest (`"test": "vitest run"`), plus `playwright": "^1.61.1"` as a devDependency. `npm run check` = `tsc --noEmit && vitest run && npm run registry:check && npm run networkapps:check && npm run egress:check`.
- Playwright: no `playwright.config.*`, no Playwright test runner — used as a bare Node script (`script/egress_browser_check.mjs`) driven via `node script/...mjs`, launched from CI's `egress_browser` job to check no network request leaves the app's own origin in a production-mode boot.
- CI (`ci.yml`): five jobs — `scan_ruby` (brakeman/bundler-audit), `check_js` (`npm run check` + `npm audit`), `lint` (rubocop), `egress_browser` (Playwright-driven Chromium egress check against a production-mode `bin/rails server`), `test` (`bin/rails db:test:prepare test`, with `bin/vite build` prebuilt for RAILS_ENV=test first to avoid Vite manifest races under parallel Minitest workers).

### diskman
- Framework: Minitest (`test/` — `clients`, `controllers`, `jobs`, `models`, `services`). No `spec/`.
- Fixtures: dir present but empty (0 `.yml`).
- System tests: none; no Capybara/Selenium in Gemfile.
- Inertia testing: `require "inertia_rails/minitest"` in `test/test_helper.rb`.
- VCR/WebMock: `gem "webmock", "~> 3.24"`, `gem "vcr", "~> 6.3"`. VCR configured with cassette dir `test/cassettes`, `hook_into :webmock`, `allow_http_connections_when_no_cassette = true` (looser than cora), one scrubber for `<APPLE_MUSIC_TOKEN>`.
- Notable: `test_helper.rb` runs `npx vite build` once in the master process before parallel workers fork (guards against ENOTEMPTY races clearing `public/vite-test`), skippable via `SKIP_VITE_TEST_BUILD=1`.
- Parallelism: `parallelize(workers: ENV["CI"] ? 1 : :number_of_processors)` — single-worker in CI due to SQLite file locking.
- Frontend: no Vitest/Jest deps found in package.json grep (no dedicated frontend test runner).
- CI: `bin/rails test` only (no system-test step, no JS test step).

### lifegarden
- Framework: Minitest (`test/` — `channels`, `controllers`, `integration`, `javascript`, `jobs`, `models`, `services`, `support`, `system`). No `spec/`. Also has a native iOS target (`Lifegarden.xcodeproj`, `LifegardenTests`, `LifegardenUITests`) — out of scope for Rails testing but notable as a non-Rails surface in the same repo.
- Fixtures: `fixtures :all`; 30 fixture files.
- System tests: Capybara + Selenium `headless_chrome` (`test/application_system_test_case.rb`), same `TrixSystemTestHelper`/`Warden::Test::Helpers`/account-switch route pattern as cora, but simpler (no remote-grid branch); explicit teardown resets `Warden.test_reset!`, `Capybara.app_host = nil`.
- Inertia testing: `require "inertia_rails/minitest"`.
- VCR/WebMock: not present. `RubyLLM.config.gemini_api_key ||= "test-key"` stubbed directly instead.
- Parallelism: `parallelize(workers: :number_of_processors)`.
- Frontend: Vitest (`vitest.config.ts`, `"test:js": "vitest run"`), `@testing-library/{dom,jest-dom,react}` in package.json.
- CI (`ci.yml`): only lint/security steps grepped (brakeman, bundler-audit, standardrb, erb_lint) — no explicit `bin/rails test` or `npm run test` line matched in the CI grep, meaning the test run step (if present) uses different wording; not confirmed present.

### thinkroom
- Framework: Minitest (`test/` — `channels`, `controllers`, `integration`, `mailers`, `services`, `test_helpers`). No `spec/`.
- Fixtures: dir present but empty (0 `.yml`).
- System tests: no `application_system_test_case.rb`, no Capybara/Selenium.
- Inertia testing: `require "inertia_rails/minitest"`.
- `test/test_helper.rb` resets shared in-memory state between tests: `WriteRateLimited::STORE.clear` and `SyncChannel::ACTIVE_SUBSCRIBERS.clear` in a global `setup` block (documented as necessary because parallel workers share one process-wide store).
- VCR/WebMock: not present in Gemfile grep.
- Parallelism: `parallelize(workers: :number_of_processors)`.
- Frontend: no Vitest/Jest; only `playwright": "^1.61.1"` as devDependency, no config or vitest.config found; `npm run check` runs TypeScript check.
- Playwright: same pattern as tada — bare Node scripts (`script/sync_check.mjs`, `link_check.mjs`, `mermaid_check.mjs`, `rich_block_width_check.mjs`, `suggestion_list_replace_check.mjs`, `export_check.mjs`, `html_document_check.mjs`, `meta_refresh_check.mjs`, `mobile_zoom_check.mjs`, `native_shell_check.mjs`, `browser_check.mjs`), run in CI's `browser_checks` job against a live `bin/vite dev` + `bin/rails server` boot, after "warming" the Vite module graph with one Playwright-launched Chromium page load.
- CI: 5 jobs — `scan_ruby`, `lint`, `test` (`npm run check` + `bin/vite build --mode test` + `bin/rails db:test:prepare test`), `scan_javascript` (npm audit), `browser_checks` (Playwright script battery above).

### riffrec-dashboard
- Framework: Minitest (`test/` — `controllers`, `jobs`, `mailers`, `models`, `services`). No `spec/`.
- Fixtures: `fixtures :all`; 6 fixture files (`agent_connections.yml`, `users.yml`, etc.).
- System tests: no `application_system_test_case.rb`; no Capybara/Selenium in Gemfile.
- Inertia testing: `require "inertia_rails/minitest"` — comment in `test_helper.rb` notes it provides `assert_inertia_props`/`assert_inertia_component`/`inertia_headers`.
- Test doubles: unusually heavy hand-rolled fakes directly in `test_helper.rb` — `FakeCursor` (records `calls`, supports `error:`/block-based responses) and `UnauthorizedHttp` (a `Net::HTTP`-shaped double returning a raw 401 to drive the real `Cursor::Client` through actual error-handling code paths rather than a hand-built error object).
- Auth-in-tests pattern: `sign_in` helper does a real `POST login_path` with fixture credentials (not session stuffing) "so a helper that writes the session directly would keep passing if `#create` stopped authenticating at all" — explicit design choice documented inline.
- Security-testing helper: `assert_no_key_material(connection, plaintext)` checks response body never leaks plaintext API key, its ciphertext, or the ciphertext's decoded payload.
- VCR/WebMock: not present.
- Parallelism: `parallelize(workers: :number_of_processors)`.
- Frontend: no Vitest/Jest test deps found in package.json grep.
- CI: `scan_ruby`, `scan_javascript` (npm audit), `lint`, `test` (`npm run check` typecheck + `bin/vite build --mode test` + `bin/rails db:test:prepare test`). Comment in CI notes deploys are deliberately manual/operator-driven, not CI-triggered.

### kieranklaassen-com
- Framework: Minitest (`test/` — `controllers`, `integration`, `models`, `repositories`). No `spec/`.
- Fixtures: dir present but empty (0 `.yml`).
- System tests: none; no Capybara/Selenium.
- Inertia testing: `require "inertia_rails/minitest"`.
- `test/test_helper.rb` is the leanest of all surveyed — just parallelize + require, no custom setup/teardown.
- VCR/WebMock: not present.
- Frontend: Vitest (`"test:frontend": "vitest run"`), `vitest": "^4.1.9"`.
- CI: `npm run test:frontend` then `bin/rails test`.

### leva
- Type: Rails **engine** (gem, `leva.gemspec`), tested against a `test/dummy` Rails app.
- Framework: Minitest (`test/` — `controllers`, `helpers`, `integration`, `jobs`, `mailers`, `models`, `services`, `leva_test.rb`).
- Fixtures: engine-style fixture loading — `ActiveSupport::TestCase.fixture_paths = [File.expand_path("fixtures", __dir__)]`, `fixtures :all`, conditional on `respond_to?(:fixture_paths=)`.
- VCR: `gem "vcr"` (comment: "VCR records real HTTP responses to replay in tests"), configured with `hook_into :faraday` (not webmock — distinct from cora/diskman), cassette dir `test/vcr_cassettes`, `record: :new_episodes`, `allow_http_connections_when_no_cassette = true`. A custom `VcrTestHelper` module auto-generates a cassette name per test (`ClassName#test_name` → `class_name/test_name`) and wraps `setup`/`teardown` with `VCR.insert_cassette`/`VCR.eject_cassette` — opt-in via module inclusion rather than global.
- RubyLLM test keys stubbed directly in `test_helper.rb` (`config.gemini_api_key = ENV.fetch(..., "test-gemini-key")`, etc.) for VCR playback.
- System tests / frontend: none — pure Ruby gem, no JS.
- CI: `bin/rails test` (run against the dummy app).

### every
- **Outlier / legacy stack.** Old Rails app, not on Inertia — uses `webpack.config.js` + `babel.config.js` directly, no Vite, no `inertia_rails` in Gemfile.
- Framework: **RSpec** is dominant (109 `*_spec.rb` files under `spec/`) but a parallel Minitest `test/` tree exists with 26 `*_test.rb` files — appears to be a mid-migration or legacy-coexistence state (both `spec/rails_helper.rb`/`spec_helper.rb` and `test/test_helper.rb` are present and functional).
- Factory library: **FactoryBot** — `gem 'factory_bot_rails'`, `spec/factories/` (e.g. `advertisements.rb`, `collections.rb`, `comments.rb`), `config.include FactoryBot::Syntax::Methods` in `rails_helper.rb`. This is the only project in the survey using FactoryBot instead of fixtures.
- System tests: Capybara + Selenium `:chrome` (not `:headless_chrome`) in `test/application_system_test_case.rb`; separately, `spec/features/` holds Capybara feature specs under RSpec (`require 'capybara/rspec'` in `rails_helper.rb`).
- VCR/WebMock: `gem 'webmock', '~> 3.13'`; `rails_helper.rb` does `require "webmock/rspec"` then immediately `WebMock.allow_net_connect!` (webmock loaded but net connect allowed by default — opposite of cora/erf-rails' `disable_net_connect!`). No VCR gem present.
- Also has `gem 'playwright-ruby-client'` in Gemfile (Ruby-side Playwright client) alongside Capybara/Selenium — two separate browser-automation stacks coexisting.
- Frontend: **Jest** (`jest": "^29.0.3"`, `jest-environment-jsdom`), config inline in `package.json`: `testEnvironment: "jsdom"`, `roots: ["spec/javascript"]`. This is the only project using Jest instead of Vitest.
- Other test-adjacent gems: `rspec-json_expectations`, `mock_redis`, `guard-rspec`.
- CI: no `.github/workflows` directory found — no CI config present for this project.

### erf-rails
- Framework: Minitest (`test/` — `clients`, `controllers`, `notifiers`, `services`, `support`, `system`). No `spec/`.
- Fixtures: `fixtures :all`; 16 fixture files.
- System tests: Capybara + Selenium `headless_chrome`, same pattern as cora/lifegarden (`TrixSystemTestHelper`, account-switch route, remote-grid branch via `CAPYBARA_SERVER_PORT`).
- VCR/WebMock: `gem "webmock", "~> ..."` only (no VCR gem in Gemfile, unlike cora/diskman/leva). `WebMock.disable_net_connect!(allow_localhost: true, allow: [...])` same allowlist pattern as cora.
- `UNIQUE_PASSWORD = Devise.friendly_token` generated to avoid Chrome's breached-password warning in system tests.
- Parallelism: `parallelize(workers: :number_of_processors)`.
- Frontend: no package.json test deps found (no Vite/JS build tooling detected at top level in this survey's grep — likely asset-pipeline or minimal JS).
- CI: only `bundle exec erb_lint --lint-all` matched in grep; other test steps (if any) use different wording, not confirmed via grep pattern used.

### blazer-ai
- Type: Rails **engine** (gem, `blazer-ai.gemspec`) extending the `blazer` gem with `ruby_llm`, tested against `test/dummy`.
- Framework: Minitest (`test/` — `blazer`, `controllers`, `generators`).
- Fixtures/FactoryBot: neither detected in gemspec or test_helper.
- `test/test_helper.rb`: minimal — `require_relative "dummy/config/environment"`, `require "rails/test_help"`, `require "minitest/autorun"`.
- VCR/WebMock: not present.
- System tests / frontend: none — pure Ruby gem, no JS.
- CI: `bundle exec rake test`.

## Recommendation for compound-stack-rails

1. **Minitest + fixtures, not RSpec/FactoryBot.** 11 of 12 projects use Minitest with Rails fixtures (`fixtures :all`); FactoryBot+RSpec appears only in `every`, the one pre-Inertia legacy app that predates the current stack. The starter should ship Minitest with a `test/fixtures/` convention, matching cora, tada, diskman, lifegarden, thinkroom, riffrec-dashboard, kieranklaassen-com, erf-rails, leva, and blazer-ai.

2. **`inertia_rails/minitest` for Inertia response assertions.** diskman, lifegarden, thinkroom, riffrec-dashboard, and kieranklaassen-com all `require "inertia_rails/minitest"` in `test/test_helper.rb` for `assert_inertia_props`/`assert_inertia_component`. Adopt this as the default rather than tada's hand-rolled `inertia_props` regex parser — it's the majority pattern and avoids reimplementing a scrubber for `<script data-page="app">`.

3. **Capybara + Selenium `headless_chrome` for system tests, when included at all.** cora, lifegarden, and erf-rails share a nearly identical `application_system_test_case.rb` (Warden test helpers, `TrixSystemTestHelper`, account-switch test route, remote-Selenium-grid branch via `CAPYBARA_SERVER_PORT`/`SELENIUM_HOST`). No project uses Cuprite. This shared file should become a template default, but note most of the *newer* Inertia apps (tada, diskman, thinkroom, riffrec-dashboard, kieranklaassen-com) skip Capybara system tests entirely in favor of Minitest integration tests plus (optionally) Playwright smoke scripts — so system tests should be an opt-in module, not mandatory scaffolding.

4. **Vitest + Testing Library for frontend, not Jest.** cora, atelier, tada, lifegarden, and kieranklaassen-com all use Vitest (`vitest.config.ts`, jsdom environment); `@testing-library/{dom,jest-dom,react,user-event}` appears wherever component tests exist (cora, lifegarden). Only the legacy `every` app uses Jest. Standardize on Vitest + RTL as the frontend test default, wired to `npm run test`/`test:frontend` in CI alongside `bin/rails test`, mirroring atelier's and kieranklaassen-com's CI (`npm run test:frontend` → `bin/rails test`).

5. **Playwright as an opt-in CI smoke-check layer, not a Rails-integrated test runner.** tada and thinkroom both add Playwright as a bare Node-script layer (`script/*_check.mjs`, no `playwright.config.*`, no Playwright test runner) run as separate CI jobs against a booted server — used for egress/regression/visual checks rather than feature coverage. This is a reasonable pattern to document as optional tooling for apps with real browser-rendering risk (canvas/editor apps like thinkroom), but shouldn't be baked into the starter's default test suite.

6. **VCR + WebMock for external API tests, cassette dir `test/vcr_cassettes` (or `test/cassettes`), `hook_into :webmock`.** cora and diskman both configure VCR this way; cora's scrubber pattern (`filter_sensitive_data` per credential + `before_record` header scrubbing for `Authorization: Bearer ...`) is the most complete example. `WebMock.disable_net_connect!(allow_localhost: true, allow: [...])` (cora, erf-rails) is a good default for apps that shouldn't hit real network in tests; leva's `hook_into :faraday` + auto-cassette-per-test pattern is worth citing as an alternative for gem-style projects that want zero-boilerplate VCR usage. Ship VCR+WebMock as an opt-in module for apps that call external/LLM APIs, not a hard default (diskman, thinkroom, riffrec-dashboard, kieranklaassen-com, tada don't use it).

7. **No coverage tool by default.** SimpleCov appears in exactly one project (cora) and is commented out/unused there. Don't add SimpleCov to the starter; if coverage is wanted later, cora's dormant Gemfile line is the only precedent to build from.

8. **Parallel test workers as default**, following the `parallelize(workers: :number_of_processors)` pattern used by tada, lifegarden, thinkroom, riffrec-dashboard, kieranklaassen-com, and erf-rails — with escape hatches for apps with shared global state (thinkroom clears in-memory stores in `setup`; atelier pins `workers: 1` because its hermetic `ERF_ROOT`/`TUIN_ROOT` state tree isn't parallel-safe; diskman caps at 1 worker under `CI` due to SQLite locking; cora caps at 15 to match Redis's 16-database limit). Document these as the known reasons to override the default rather than leaving parallelism unexplained.
