# compound-stack-rails

The canonical Rails starter the fleet converges on: **Rails 8.1 + Inertia/React +
Kamal + the house libraries**, structured as independently adoptable modules, with
an **agent-executable changelog** as the upgrade delivery mechanism.

- **New apps** clone this repo and are born with a complete manifest.
- **Existing apps** adopt modules à la carte and receive upgrades as reviewable
  PRs driven by agents reading this repo's changelog against their manifest.

## Stack

Ruby 4.0.7 · Node 24 LTS · Rails ~> 8.1 · SQLite + solid_cache/queue/cable · Propshaft ·
Inertia.js + Vite + React 19 + TypeScript + Tailwind v4 (`app/frontend`, SSR
wired-off) · Rails 8 session auth (hardened, no open registration) · Solid Queue
in Puma · Minitest + Vitest · Kamal 2.12 (env-driven) · `ruby_llm` first-class ·
[Geneva Drive](https://github.com/julik/geneva_drive) durable workflows (LGPLv3
or separately commercially licensed) · installable PWA (manifest + Inertia-safe
service worker) · riffrec feedback capture (no-op until configured) · Flipper
feature flags (per-user actors, doc-first) · WebMCP + MCP agent tools from one
registry (`app/tools/`, official `mcp` gem).

## Quickstart

```sh
bin/setup            # install deps, prepare the database
bin/dev              # boot Rails + Vite (open http://localhost:3100)
bin/rails test       # Ruby suite
npm run check        # tsc x2 + Vitest
```

Create a user (there is no open registration):

```sh
EMAIL=you@example.com PASSWORD='a-long-password' bin/rails users:create
```

## Modules

Every stack area is an independently adoptable module with a boundary doc in
[`docs/modules/`](docs/modules/README.md): frontend, auth, jobs, testing, ci,
deploy, ruby_llm, serialization, riffrec, ruby_native, copse, geneva_drive, pwa,
feature_flags, webmcp, and agent-conventions. Each doc says what the module is, its
exact file boundary, how to adopt it into an existing app, and how to verify.

## How upgrades flow

- [`.template-manifest.yml`](.template-manifest.yml) records the template version
  an app is on and which modules it has adopted. A clone is **born complete** —
  every module listed at the current version. See
  [docs/template-manifest.md](docs/template-manifest.md).
- [`docs/changelog/`](docs/changelog/README.md) holds entries written as
  **imperative upgrade instructions an agent executes** against a downstream app
  (not human release notes). An upgrade agent selects entries newer than an app's
  manifest version, filtered to its adopted modules, applies them, bumps the
  manifest, and opens a **reviewable PR — never a direct push**.

## For agents

Read [`AGENTS.md`](AGENTS.md) first (`CLAUDE.md` symlinks to it). Key rules:
Rails owns routes and props (no parallel JSON API); never commit or push to
`main`; deploy is fully env-driven with no committed secrets.
