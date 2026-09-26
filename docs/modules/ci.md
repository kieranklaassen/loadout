# Module: ci

A GitHub Actions workflow that mirrors the local gates. Four jobs, every action
pinned to a commit SHA, and the Vite test build run **before** the Ruby test run
to avoid a parallel-worker autoBuild race.

## What this module is

`.github/workflows/ci.yml` runs on `pull_request` and `push` to `main`:

- **scan_ruby** — `bin/brakeman` (static analysis) + `bin/bundler-audit` (known gem CVEs).
- **lint** — `bin/rubocop -f github`, with a RuboCop cache keyed on
  `.ruby-version` + `.rubocop.yml` + `.rubocop_todo.yml` + `Gemfile.lock`, busted
  by `github.run_id` on the default branch.
- **check_js** — `npm ci`, `npm run check` (tsc ×2 + Vitest), and
  `npm audit --omit=dev --audit-level=moderate`.
- **test** — `bin/vite build --mode test` **then** `bin/rails db:test:prepare test`.

## Why the Vite pre-build matters

Vite Ruby's `autoBuild` builds the manifest on the first request that needs it.
Under `parallelize`, several test workers hit that first request at once and race
to build the same manifest. Building `--mode test` up front makes the manifest
already present, so no worker triggers a build.

## Security posture

- Every `uses:` is pinned to a 40-character commit SHA with a version comment.
  A moving tag (`@v4`) can be repointed at malicious code by a compromised action
  repo; a SHA cannot. `test/ci/workflow_test.rb` enforces this.
- `ruby/setup-ruby` with `bundler-cache: true`; `actions/setup-node` with
  `cache: npm` and `node-version-file: .node-version`.

## Files (the module boundary)

- `.github/workflows/ci.yml`
- `.node-version` (single-sources the CI Node version)
- `test/ci/workflow_test.rb`

## Adopt into an existing app

1. Copy `.github/workflows/ci.yml` and `.node-version`.
2. Ensure `bin/brakeman`, `bin/bundler-audit`, `bin/rubocop`, `bin/vite` binstubs exist.
3. Keep the SHA pins; run `test/ci/workflow_test.rb` to enforce them.

## Verify adoption

- The workflow YAML parses and `bin/rails test test/ci/workflow_test.rb` passes.
- Locally, the same gates pass: `bin/brakeman`, `bin/bundler-audit`, `bin/rubocop`,
  `npm run check`, `bin/rails test`.

## Opt-in

- **system_test** job — commented out in the workflow; enable it (and add
  `ApplicationSystemTestCase` tests) when a flow needs a real browser.
- No build matrix by default; add one only when multi-version support is a goal.
