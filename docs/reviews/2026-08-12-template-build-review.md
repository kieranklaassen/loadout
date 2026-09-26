# Template Build Review — Compound Stack Rails (14-unit build)

- **Date:** 2026-08-12
- **Scope:** Merge of `feat/compound-stack-rails-template` into `main` (`git diff 3e90c80..main` — 180 files, ~8,900 insertions).
- **Plan:** `docs/plans/2026-08-11-001-feat-compound-stack-rails-template-plan.md` (`ce-unified-plan/v1`, `artifact_readiness: implementation-ready`).
- **Mode:** Multi-agent code review — correctness/security/reliability, secrets + template-system integrity + requirements completeness, frontend + test coverage, project-standards + CI + docs quality.
- **Head:** `50be5fd`.

## Verdict

**Ready with fixes.** No P0. Requirements R1–R9 are all met and every implementation unit U1–U14 is present with substance; template-system integrity (manifest ↔ module-docs ↔ changelog 1:1) and the secret/endpoint gate both pass cleanly. One P1 security divergence (production SSL disabled) should be fixed before any real Kamal deploy — the branch is already merged, so all findings below are advisory follow-ups rather than merge blockers.

The single most important thing to do: **uncomment `config.assume_ssl` / `config.force_ssl` in `config/environments/production.rb`** (finding #1).

---

## Findings

### P1 — High

**#1 — Production SSL is disabled while `deploy.yml` claims it is enforced; auth session cookie ships without `Secure`.**
`config/environments/production.rb:28,31` — both `# config.assume_ssl = true` and `# config.force_ssl = true` are commented out. Rails 8's generated `production.rb` ships these *uncommented*; this template commented them out.
- **Contradiction:** `config/deploy.yml:30` states `# Requires config.assume_ssl + config.force_ssl in production.rb (Rails default).`
- **Failure scenario:** The `session_id` cookie (the entire auth token) is set at `app/controllers/concerns/authentication.rb:44` with `httponly: true, same_site: :lax` and **no `secure: true`**. `force_ssl` is what globally upgrades `Set-Cookie` to `Secure` and emits HSTS. With it off, any plaintext HTTP request to the app can leak the session cookie, and no HSTS means a first-visit SSL-strip is possible. `assume_ssl` off also makes Rails treat proxied requests as HTTP, defeating secure-cookie logic. `kamal-proxy ssl: true` terminates TLS at the edge but does not substitute for app-level enforcement in an authenticated-by-default template.
- **Fix:** Uncomment `config.assume_ssl = true` and `config.force_ssl = true` in `production.rb` (matches the deploy.yml comment and Rails 8 defaults). The `config.ssl_options` `/up` exclude on line 34 can also be restored so healthchecks skip the redirect. No change needed at the cookie call site once `force_ssl` upgrades cookies globally. **Decision gate** (auth/security) — verify against the intended proxy topology.

### P2 — Moderate

**#2 — `RIFFREC_API_KEY` is modeled as both a server secret and a browser-shipped value — downstream leak footgun.**
`config/initializers/riffrec.rb:26` maps `ENV["RIFFREC_API_KEY"]` → `public_key` in `client_config`, which `app/controllers/inertia_controller.rb:26` ships to the browser via `inertia_share riffrec`. The *same* variable is declared a Kamal **secret** in `config/deploy.yml:49` (`env.secret`) and in `.kamal/secrets`. No real value is committed, so **R9 is satisfied and the template itself leaks nothing** — but the pattern is internally inconsistent: an adopter who supplies a genuinely secret capture key (which the `env.secret` framing signals is expected) would publish it straight into page props. The guard in `test/controllers/riffrec_share_test.rb` only checks the key *name* isn't secret-shaped (`public_key` passes); it never checks value sensitivity.
- **Fix:** If this is a publishable key, rename it `RIFFREC_PUBLIC_KEY`/`RIFFREC_PUBLISHABLE_KEY`, move it from `env.secret` to `env.clear` in `deploy.yml`, drop it from `.kamal/secrets`, and state in `docs/modules/riffrec.md` that it is browser-safe, not a server secret. **Decision gate** — resolve before downstream apps copy the pattern with a real key.

**#3 — `ruby_llm.rb` sets `model_registry_class = "Model"` but the template ships no `Model` class — latent runtime `NameError`.**
`config/initializers/ruby_llm.rb:23` — `config.model_registry_class = "Model"`. `app/models/` contains only `application_record`, `current`, `session`, `user`. The value is constantized lazily, so it does **not** break boot or CI (verified). But the first template user who actually uses `ruby_llm` with `use_new_acts_as = true` (persisting a chat/message or hitting the DB-backed registry) triggers `"Model".constantize` → `NameError: uninitialized constant Model`. The module is wired in and advertised as ready-to-use.
- **Fix:** Ship the `Model`/`Chat`/`Message` registry models, or drop `model_registry_class`/`use_new_acts_as` until they exist, or document that adopting `ruby_llm` requires generating the registry models first.

**#4 — Auth sign-in submit path is entirely untested.**
`app/frontend/pages/auth/sign_in.test.tsx` fully mocks `@inertiajs/react`, stubbing `useForm` with a `vi.fn()` `post`. No test ever submits the form, so nothing verifies `event.preventDefault()` runs (a regression dropping it makes the browser do a native `GET /`, silently breaking sign-in) or that the form posts to `'/session'` (`sign_in.tsx:15`). This is the security-load-bearing page; the two existing tests only assert static rendering and that a hardcoded `flash.alert` renders.
- **Fix:** Render, capture the mocked `post`, `fireEvent.submit` the form, and assert `post` was called with `'/session'`. **Mechanical.**

**#5 — `AGENTS.md` module enumeration omits `frontend` (lists 9, should be 10).**
`AGENTS.md:49-51` — `one doc per adoptable module (auth, jobs, testing, ci, deploy, ruby_llm, riffrec, serialization, agent-conventions)`. The manifest, `docs/modules/README.md`, and `README.md` all list **10** modules; `frontend` is missing here. Since AGENTS.md is the canonical agent-facing guide, an incomplete enumeration can mislead an adopting agent into thinking there is no `frontend` boundary doc (there is: `docs/modules/frontend.md`).
- **Fix:** Insert `frontend` at the front: `(frontend, auth, jobs, testing, ci, deploy, ruby_llm, serialization, riffrec, agent-conventions)`. **Mechanical.**

### P3 — Low

**#6 — CSR/SSR branch + `RiffrecProvider` wrap in the entrypoint has no coverage.**
`app/frontend/entrypoints/inertia.tsx:46-50` (the `el.dataset.serverRendered === 'true'` → `hydrateRoot` vs `createRoot` decision) is the one piece of glue with a real branch and no test. Logic reads correctly. Acceptable for a template; noted as a coverage gap.

**#7 — `SharedProps = {}` is typed as "any non-nullish value," not an empty object.**
`app/frontend/types/index.ts:6`. Meanwhile `inertia.tsx:30-33` reads `feedback_capture_enabled`/`riffrec` off `initialPage.props` via an inline `as` cast. Hoisting these genuinely-shared props into `SharedProps` (`{ feedback_capture_enabled?: boolean; riffrec?: RiffrecConfig | null }`) would give the entrypoint real typing and make the `{}` type meaningful.

**#8 — `riffrec_provider.test.tsx` "enabled" test cannot fail meaningfully.**
`app/frontend/lib/riffrec_provider.test.tsx:16-27` asserts only that children render when `enabled`. Because the provider's effect is an intentional no-op stub, the test passes regardless of what the enabled branch does. Honest for the stub; flag for when the real widget lands (mock the widget module, assert mount/unmount).

**#9 — Rename guidance omits the PWA manifest.**
`docs/template-manifest.md:42-45` lists `config/application.rb`, `config/database.yml`, `config/cable.yml`, and Kamal env values in the rename checklist, but `app/views/pwa/manifest.json.erb:2,19` also hardcodes `"CompoundStackRails"` and is not mentioned. A renamed clone ships a PWA manifest still branded `CompoundStackRails`.
- **Fix:** Add `app/views/pwa/manifest.json.erb` to the rename checklist. **Mechanical.**

**#10 — `.env.example` comment nit.**
`.env.example:20` — cosmetic wording; the gating logic (`configured?` requires both riffrec vars) is correct. No action required.

---

## Requirements Completeness (plan is implementation-ready)

All requirements met; all implementation units present and substantive.

| ID | Status | Evidence |
|----|--------|----------|
| R1 runnable / boots / deploys | met | `Gemfile`, `config/database.yml` (4 SQLite dbs), `config/deploy.yml`, `Dockerfile`, full Rails skeleton |
| R2 modules with docs | met | 10 `docs/modules/*.md`, each with Adopt + Verify sections |
| R3 agent-executable changelog | met | `docs/changelog/README.md` (imperative-body rule), seed entry |
| R4 manifest | met | `.template-manifest.yml` (version + modules map) |
| R5 filter algorithm | met | changelog README filter+apply section; `changelog_test.rb` |
| R6 reviewable PRs | met | documented in seed entry, changelog README, `AGENTS.md` |
| R7 born-complete manifest | met | manifest lists all 10 modules at 0.1.0; `manifest_test.rb` |
| R8 adopt single module | met | Adopt sections in every doc; AE2 shape |
| R9 riffrec, no secrets | met (see #2) | `riffrec.rb` no-op-degrading; no committed key/endpoint |

U1–U14: all present. U1 skeleton, U2 Inertia/Vite/React/TS/Tailwind, U3 SSR-off + timeout patch, U4 auth (no registration route), U5 jobs (`config/schedule.rb` correctly absent), U6 testing, U7 CI, U8 deploy, U9 ruby_llm/serialization, U10 riffrec, U11 agent-conventions, U12 module registry, U13 manifest, U14 changelog — each backed by the files and tests the plan names.

---

## Coverage & Clean Areas

**Secret/endpoint gate — PASS.** Tree-wide grep for key/token/PEM/bearer shapes returned zero hits. `.kamal/secrets` is shell-indirection only; `.env.example` carries names with empty values; `config/deploy.yml` is fully env-driven; `config/master.key` is untracked and gitignored (`.gitignore:43`); `config/credentials.yml.enc` is a normal encrypted blob. All hostnames are placeholders (`riffrec.example.com`).

**Template-system integrity — PASS.** Manifest keys `{frontend, auth, jobs, testing, ci, deploy, ruby_llm, serialization, riffrec, agent-conventions}` (10) exactly equal the `docs/modules/*.md` basenames (minus README). Changelog referential integrity, semver validation, seed-entry version match, and `CLAUDE.md → AGENTS.md` symlink all confirmed and test-enforced.

**CI — PASS on every called-out point.** Four jobs (`scan_ruby`/`lint`/`check_js`/`test`); every `uses:` pinned to a 40-char commit SHA; `bin/vite build --mode test` runs before `bin/rails db:test:prepare test` (autoBuild race averted); triggers `pull_request` + `push:[main]`; brakeman + bundler-audit + `npm audit` present. `test/ci/workflow_test.rb` genuinely asserts both the job skeleton and SHA-pinning.

**Verified clean:** auth enumeration/timing (byte-identical failure message, dummy bcrypt), password byte-limit + minimum-length validations, rate-limit store correctness given `WEB_CONCURRENCY: "1"`, auth gate default-on via `InertiaController`, `inertia_ssr_timeout.rb` monkeypatch, boot with empty environment, `recurring.yml` per-env keys + evaluable prune command, `queue.yml` env resolution, `deploy.yml` fail-loud on missing `KAMAL_*`, `users.rake`, migrations/schema consistency, Dockerfile (ruby:3.4.2-slim, sqlite3, EXPOSE 80, thruster CMD), `.gitignore` completeness, and correct Inertia frontend patterns (`useForm`/`Form`, no react-hook-form, no `useEffect`+fetch). `npm run check` (tsc ×2 + Vitest) reported green.

**Not executed:** `bin/rails test` and a live boot were not run — the local environment has only system Ruby 2.6 (no project bundler). R1's "boots" claim and the Ruby suite are verified by inspection and the tests' own structure, not a live run.

---

## Actionable Follow-ups (prioritized)

1. **#1 (P1)** `config/environments/production.rb:28,31` — uncomment `assume_ssl`/`force_ssl`. *Decision gate — verify proxy topology.*
2. **#3 (P2)** `config/initializers/ruby_llm.rb:23` — resolve missing `Model` registry class before the LLM module is adopted.
3. **#2 (P2)** riffrec key naming/secret-vs-clear consistency across `riffrec.rb` / `deploy.yml` / `.kamal/secrets` / `docs/modules/riffrec.md`. *Decision gate.*
4. **#4 (P2)** `app/frontend/pages/auth/sign_in.test.tsx` — add a submit-contract test. *Mechanical.*
5. **#5 (P2)** `AGENTS.md:49` — add `frontend` to the module list. *Mechanical.*
6. **#6–#10 (P3)** coverage/typing/doc nits at the author's discretion.
