# Module: testing

Two test toolchains: **Minitest + fixtures** for Ruby (with Inertia assertions),
and **Vitest + React Testing Library + jsdom** for the frontend. Both are wired
into the same gates CI runs.

## What this module is

- `test/test_helper.rb`: `fixtures :all`, `require "inertia_rails/minitest"` (so
  integration tests can assert `assert_inertia_component` / `assert_inertia_props`),
  and `parallelize(workers: :number_of_processors)`.
- Vitest with `environment: 'jsdom'`, a setup file registering
  `@testing-library/jest-dom` matchers and running `cleanup` after each test, and
  an include glob of `app/frontend/**/*.{test,spec}.{ts,tsx}`.
- `npm run test` runs Vitest; `npm run check` runs both tsconfigs + Vitest — the
  single frontend gate.

## Files (the module boundary)

- `test/test_helper.rb`, `test/test_helpers/session_test_helper.rb`
- `vitest.config.ts`, `app/frontend/test/setup.ts`
- `test/fixtures/*.yml`
- Component tests colocated with pages (e.g. `app/frontend/pages/**/*.test.tsx`).

## Adopt into an existing app

1. Ruby: add `require "inertia_rails/minitest"` and `fixtures :all` to
   `test/test_helper.rb`.
2. Frontend: `npm add -D vitest @testing-library/react @testing-library/jest-dom @testing-library/user-event jsdom`,
   copy `vitest.config.ts` + `app/frontend/test/setup.ts`, and add the `test` /
   `check` scripts to `package.json`.

## Verify adoption

- `bin/rails test` runs green under parallel workers.
- `npm run test` runs green.
- `npm run check` (tsc ×2 + Vitest) runs green.

## Known parallelize override cases

`parallelize(workers: :number_of_processors)` is on by default. Override it to a
single worker (`parallelize(workers: 1)` in a specific `TestCase`, or the
`PARALLEL_WORKERS=1` env) when:

- a test depends on a **process-shared in-memory store** (e.g. an owned
  `MemoryStore` for rate limiting) and needs deterministic counts across
  requests — reset the store in `setup` rather than disabling parallelism where
  possible;
- SQLite lock contention appears under load in CI (each worker gets its own
  database, but heavy shared-connection tests can still contend).

## Opt-in add-ons (not shipped by default)

- **System/browser tests** (`capybara` + `selenium-webdriver` are in the Gemfile):
  add `test/application_system_test_case.rb` and write `ApplicationSystemTestCase`
  tests when a flow genuinely needs a real browser.
- **HTTP recording** (`vcr` + `webmock`): add when tests hit external services.
