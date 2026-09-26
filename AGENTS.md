# AGENTS.md

Canonical, tool-agnostic guide for agents and humans working in this repo.
`CLAUDE.md` is a symlink to this file.

## Architecture in one line

Rails owns routes and props; React pages render those props. There is **no
parallel JSON API** — a page never fetches its own data; the controller passes it
via `render inertia:`.

## Local development

```sh
bin/dev          # boots Rails (web) + Vite together via Procfile.dev
```

- Open **http://localhost:3100** (or the printed port), not `127.0.0.1` — a route
  redirects `127.0.0.1` → `localhost` so the browser and the Vite dev server
  share one origin. Vite dev runs with `skipProxy` (see `config/vite.json`), so
  it serves assets directly rather than through Rails.
- Ruby tests: `bin/rails test`. Frontend gate: `npm run check` (tsc ×2 + Vitest).

## Git workflow guardrail

**Never commit or push to `main`.** Branch first (`feat/…`, `fix/…`), commit
there, and open a PR. This holds for agents and humans alike.

## Users & auth

There is **no open registration**. Create users only with:

```sh
EMAIL=you@example.com PASSWORD='a-long-password' bin/rails users:create
```

Every Inertia page is authenticated by default (the gate lives on
`InertiaController`); make a page public with `allow_unauthenticated_access`.

## Agent tools (WebMCP + MCP)

App capabilities an agent may call live in `app/tools/`, **one registry for both
surfaces** (see [docs/modules/webmcp.md](docs/modules/webmcp.md)):

- Add a tool with `bin/rails g tool Name`. It subclasses `ApplicationTool`
  (an `MCP::Tool`) and is listed in `ToolRegistry::TOOLS`. Never define tool
  schemas or descriptions anywhere else, including the frontend.
- Tools run as the signed-in `user`: scope every query to it, keep
  `additionalProperties: false`, and set `read_only_hint: true` only when the
  tool never writes.
- Signed-in pages get the manifest as the `webmcp` shared prop, and
  `WebmcpProvider` registers it on the browser's model context. The
  browser calls `POST /webmcp/tools/:name` (session + CSRF). That endpoint is
  the one sanctioned exception to "no parallel JSON API"; do not add others for tools.
- MCP clients get the same tools from `ToolRegistry.mcp_server(user:)`.

## Deploying

Kamal 2.12+, fully env-driven. See **[DEPLOYING.md](DEPLOYING.md)** for the
runbook. `config/deploy.yml` reads every tenant value from `ENV` with no default,
so a missing variable fails the render loudly rather than leaking another app's
config. Secrets resolve at deploy time via shell indirection — none are committed.

## Documented knowledge

- **[docs/modules/](docs/modules/)** — one doc per adoptable module (frontend,
  auth, jobs, testing, ci, deploy, ruby_llm, serialization, riffrec,
  ruby_native, copse, geneva_drive, pwa, feature_flags, webmcp, agent-conventions), each
  with its file boundary and an "Adopt into an existing app" section.
- **[docs/solutions/](docs/solutions/)** — durable, dated write-ups of solved
  problems (YAML frontmatter; see the README there).
- **[CONCEPTS.md](CONCEPTS.md)** — the project's shared vocabulary.
- **[docs/changelog/](docs/changelog/)** — agent-executable upgrade entries. See
  its README for the version+module filter algorithm. Upgrades land as reviewable
  PRs on downstream apps, **never direct pushes**.

## Template upgrades

This repo is the fleet template. Downstream apps carry a
`.template-manifest.yml`; an upgrade agent reads changelog entries newer than an
app's manifest version (filtered to its adopted modules), applies them, bumps the
manifest, and opens a PR.
