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

There is **no registration route and no password**. Members arrive through Sign
in with Every (`Sessions::EveryController`): the first successful sign-in creates
the `User`, and only a verified `@every.to` address counts as the Every team. In
development, and only there, the sign-in page also lists users under "Dev login"
(`bin/rails db:seed` creates demo members).

**Signed in at Every means signed in here** (`EverySilentSignIn`). Every page
carries `silent_sign_in_path` when an attempt is due, and the browser then asks
Every once, with `prompt=none`, from a hidden frame (`lib/silent_sign_in.ts`,
started in the browser entrypoint, never in the server render). The frame goes
to `Sessions::SilentController`, on to Every, and back to the same controller,
which answers one tiny page that says `signed_in` or `signed_out`; the page
around the frame reads it and, when signed in, reloads its props. A member who
has not finished onboarding is sent to `/welcome` by that reload, as after a
clicked sign-in. Keep to these:

- A public page (Home, a Kind, a profile, the not-found page) never redirects
  to every.to and its server-rendered HTML does not depend on the attempt:
  crawlers, link previews and anyone Every does not know must see the page as
  it is. Only the sign-in page asks by redirect, which also covers a signed-out
  visit to a gated page.
- The framed attempt has its own state (a `silent.` prefix and its own
  `__Host-` cookie) and never reads or writes the Rails session or OmniAuth's
  session keys, so it cannot break a clicked sign-in that overlaps it. Its
  outcome is never a redirect, a flash or an alert.
- `every_silent_tried` says an attempt was made (`asking` set by the browser,
  `tried` for ten minutes, `declined` for a day); `every_signed_out` says the
  person signed out here, and nothing signs them back in but their own click.
- The tiny page is the one non-Inertia page of sign-in and carries no script.
  `Sessions::SilentController` is not an `InertiaController`, so the onboarding
  gate does not apply to it; both paths create the member through
  `sign_in_from_every`, so the team rule is the same.

Admins are `users.admin`, or an address in `ADMIN_EMAILS` once Every verified
it. Remove someone who left Every with
`EMAIL=person@every.to bin/rails toolbox:remove_member` (see DEPLOYING.md).

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
- **Agent writes are suggestions.** The one write tool, `suggest_picks`, goes
  through `Toolbox::Update`, where sources `mcp` and `webmcp` may run only
  `suggest` and `withdraw`; the member confirms on the web. Confirm, dismiss,
  remove, move, visibility, handle, bio, history export, account deletion and
  agent revocation are web-only: never add a registry tool for them. Read tools
  call the shared query objects (`TeamRankings`, `Audience`) as the acting
  member, so an agent sees what the member sees on the site.
  `Agents::Capabilities` is the one source for the consent and Agents-page
  "can / can't" copy, and its test ties each line to the registry.
- Signed-in pages get the manifest as the `webmcp` shared prop, and
  `WebmcpProvider` registers it on the browser's model context. The
  browser calls `POST /webmcp/tools/:name` (session + CSRF). That endpoint is
  the one sanctioned exception to "no parallel JSON API"; the history download
  is the second sanctioned non-Inertia response. Do not add others for tools.
- MCP clients get the same tools from `ToolRegistry.mcp_server(user:, source: "mcp", client_name:, oauth_client_id:)`,
  served at `/mcp` behind the in-app OAuth 2.1 server (`McpController`).

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
- **[docs/changelog/](docs/changelog/)** — the template's upgrade entries, up to
  the version this app runs. Toolbox adds none of its own (see below).

## Template upgrades

This repo is Toolbox, an app started from compound-stack-rails 0.8.0, not the
template. `.template-manifest.yml` records the template version it runs; an
upgrade agent applies the template's newer changelog entries for the adopted
modules, bumps the manifest, and opens a reviewable PR, **never a direct push**.
Toolbox's own changes get no `docs/changelog/` entry and no manifest bump.

`docs/modules/frontend.md`, `feature_flags.md` and `webmcp.md` now also describe
Toolbox's own changes, so adapt an upgrade entry that touches those modules
rather than applying it as written. `auth` was replaced by Sign in with Every;
`docs/modules/auth.md` still describes the template's password sign-in.

`@tailwindcss/typography` was removed from the frontend: no page uses `prose`,
and its pinned parser failed `npm audit`. Add it back with the page that needs it.
