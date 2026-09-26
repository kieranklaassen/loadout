# Loadout

**What's in your AI loadout?** Loadout is a profile for the AI tools and models you actually use, per task: coding, knowledge work, writing, research, classification, image, video, animation, text to speech, speech to text, music.

- Sign in with Every, claim `loadout.every.to/<you>`, and tap your tools in about a minute.
- Or connect your agent (Claude, Claude Code, Cursor, Codex) over MCP with a normal sign-in, and let it fill your loadout in.
- Profiles are private by default. Make yours public to share it, with a generated link-preview card.
- Every staff see **the Every map**: the most-used tools and models per category, who uses what, and what they might be missing.
- Every change is kept with its date, so later we can show who switched when a new model shipped.

Built on [compound-stack-rails](https://github.com/kieranklaassen/compound-stack-rails) 0.8.0: Rails 8.1, Inertia, React 19, Tailwind 4, SQLite, and Kamal. The plan lives in [`docs/plans/2026-09-26-001-feat-loadout-v1-plan.md`](docs/plans/2026-09-26-001-feat-loadout-v1-plan.md).

## Local development

```sh
bin/setup            # install deps, prepare the database
bin/rails db:seed    # the catalog plus demo members
bin/dev              # boot Rails + Vite (open http://localhost:3100)
bin/rails test       # Ruby suite
npm run check        # tsc x2 + Vitest
```

Sign in with Every is the only production login. Locally, the sign-in page lists the seeded members under "Dev login". To try real Every sign-in, set the `EVERY_OAUTH_*` and `PUBLIC_BASE_URL` variables from `.env.example`.

## Connect an agent (MCP)

The MCP server is `https://loadout.every.to/mcp` (Streamable HTTP). It uses the MCP authorization spec: OAuth 2.1 with PKCE and dynamic client registration. There are no tokens to paste. Your client opens a browser, you sign in with Every, and you approve.

| Client | How |
|---|---|
| Claude (claude.ai, desktop) | Settings → Connectors → Add custom connector → `https://loadout.every.to/mcp` |
| Claude Code | `claude mcp add --transport http loadout https://loadout.every.to/mcp` |
| Cursor | "Add to Cursor" on `/agents`, or `{"mcpServers": {"loadout": {"url": "https://loadout.every.to/mcp"}}}` |
| Codex | `codex mcp add loadout --url https://loadout.every.to/mcp` |

Then ask: *"Fill in my Loadout from what you know about how I work. Ask me before you guess."*

The tools are `list_categories`, `search_catalog`, `get_my_loadout`, `update_loadout` and `get_recent_changes`. The same tools are exposed through WebMCP while you are signed in on the site. Connected agents are listed, and can be revoked, at `/agents`.

## Catalog

`config/catalog.yml` seeds categories, tools and models. It syncs on `db:seed` and is idempotent. Members can add anything missing while picking; those items show immediately and wait for review at `/admin/catalog_items`. Admins come from the `ADMIN_EMAILS` env var or `users.admin`. Tool marks are typographic tiles, not third-party logos.

## Deploy

See [DEPLOYING.md](DEPLOYING.md). Loadout deploys with Kamal to Hetzner, like happyhappy. Before the first deploy, Kieran needs:

- **DNS:** an `A` record for `loadout.every.to` pointing at the Hetzner server's IPv4 address (add an `AAAA` record for IPv6 if the server has one). kamal-proxy issues the Let's Encrypt certificate.
- **Every OAuth client:** redirect URI `https://loadout.every.to/auth/every/callback`, scope `basic_profile`. Put its id and secret in `EVERY_OAUTH_CLIENT_ID` and `EVERY_OAUTH_CLIENT_SECRET`.
- **Env:** `PUBLIC_BASE_URL=https://loadout.every.to`, `EVERY_OAUTH_BASE_URL=https://every.to`, and `ADMIN_EMAILS=kieran@every.to`.

## For agents

Read [`AGENTS.md`](AGENTS.md) first. The one write path for loadouts is `Loadouts::Update` (`app/services/loadouts/update.rb`). Web pickers, MCP and WebMCP all go through it, and it records the dated history in `entry_changes`.
