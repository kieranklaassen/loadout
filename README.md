# Toolbox

**The AI tools Every uses.** Toolbox shows which AI tools and models the Every team uses for each of 11 kinds of work (coding, knowledge work, writing, research, classification, image, video, animation, text to speech, speech to text, music), and lets each person share what is in their own AI toolbox.

- Home is the team page: the most used tool and model per kind of work as plain counts ("5 of 6 use it"), the latest model launches, an Overall top 10, and filters for who is counted. Each kind has its own page with who ranks what first, second and third, and how people set their tools up.
- Sign in with Every, claim `toolbox.every.to/<you>`, and rank up to three picks per kind of work in about a minute. A pick is a tool (Cursor), optionally with the model behind it (Claude Opus 5.5), a context size and an effort.
- Or connect your agent (Claude, Claude Code, Cursor, Codex) over MCP with a normal sign-in. It can only suggest picks: nothing shows on your page until you confirm it on the site.
- Pages are private by default. Choose Only me, Every team or Anyone with the link, and only people who chose to share are counted. The link-preview card is served only for Anyone with the link.
- Tools and models show their real marks where the catalog has one, and a serif initial otherwise. The look is "Every dark".
- Every change to your picks is kept with its date, so a kind's page can show what the team used before a new model shipped.

Built on [compound-stack-rails](https://github.com/kieranklaassen/compound-stack-rails) 0.8.0: Rails 8.1, Inertia, React 19, Tailwind 4, SQLite, and Kamal. The plans live in [`docs/plans/`](docs/plans/) (the v1 plan, then the Every Toolbox redesign), and the design of record is in [`docs/design/every-loadout/`](docs/design/every-loadout/).

## Local development

```sh
bin/setup            # install deps, prepare the database
bin/rails db:seed    # the catalog plus demo members
bin/dev              # boot Rails + Vite (open http://localhost:3100)
bin/rails test       # Ruby suite
npm run check        # tsc x2 + Vitest
```

Sign in with Every is the only production login. Locally, the sign-in page lists the seeded members under "Dev login"; they have mixed visibility, ranked picks and two open suggestions. To try real Every sign-in, set the `EVERY_OAUTH_*` and `PUBLIC_BASE_URL` variables from `.env.example`. Every team status needs a verified `@every.to` email, so a local sign-in with another address counts as "Everyone else".

## Connect an agent (MCP)

The MCP server is `https://toolbox.every.to/mcp` (Streamable HTTP; the host is whatever `PUBLIC_BASE_URL` says). It uses the MCP authorization spec: OAuth 2.1 with PKCE and dynamic client registration. There are no tokens to paste. Your client opens a browser, you sign in with Every, and you approve.

| Client | How |
|---|---|
| Claude (claude.ai, desktop) | Settings → Connectors → Add custom connector → `https://toolbox.every.to/mcp` |
| Claude Code | `claude mcp add --transport http toolbox https://toolbox.every.to/mcp` |
| Cursor | "Add to Cursor" on `/agents`, or `{"mcpServers": {"toolbox": {"url": "https://toolbox.every.to/mcp"}}}` |
| Codex | `codex mcp add toolbox --url https://toolbox.every.to/mcp` |

Then ask: *"Suggest picks for my Toolbox from what you know about how I work. Ask me before you guess, and I'll confirm them on the site."*

The tools are `list_categories`, `search_catalog`, `get_my_toolbox`, `get_team_rankings`, `get_recent_changes` and `suggest_picks`. `suggest_picks` is the only write, and it only proposes: you confirm or dismiss each suggestion in the Rank editor, and confirming, removing, moving, visibility and revoking are web-only. `get_team_rankings` returns what Home and the kind pages show, as you would see it. The same tools are exposed through WebMCP while you are signed in on the site. Connected agents are listed, and can be revoked, at `/agents`.

## Catalog

`config/catalog.yml` seeds categories, tools and models, including which real mark each item shows. It syncs on `db:seed` and on every deploy, and is idempotent. Members can add anything missing while picking; those items show to that member as pending and wait for review at `/admin/catalog_items`. Admins come from the `ADMIN_EMAILS` env var (an address counts only once Every verified it) or `users.admin`. Admins also set a model's release date and Vibe Check link there: a model is listed as a launch on Home only when it has both, and the link must be https on an allowed host (`every.to` and `checks.every.to`, or the hosts in `VIBE_CHECK_HOSTS` when that is set).

## Screenshots

The marketing screenshots in `docs/screenshots/` are from v1 (light theme, the members-only map). They predate the redesign and are not yet regenerated.

## Deploy

See [DEPLOYING.md](DEPLOYING.md). Toolbox deploys with Kamal to Hetzner, like happyhappy. Before the first deploy, Kieran needs:

- **DNS:** an `A` record for `toolbox.every.to` pointing at the Hetzner server's IPv4 address (add an `AAAA` record for IPv6 if the server has one). kamal-proxy issues the Let's Encrypt certificate.
- **Every OAuth client:** redirect URI `https://toolbox.every.to/auth/every/callback`, scopes `basic_profile openid` (see DEPLOYING.md for silent sign-in). Put its id and secret in `EVERY_OAUTH_CLIENT_ID` and `EVERY_OAUTH_CLIENT_SECRET`.
- **Env:** `PUBLIC_BASE_URL=https://toolbox.every.to` (required in production), `EVERY_OAUTH_BASE_URL=https://every.to`, and `ADMIN_EMAILS=kieran@every.to`.

## For agents

Read [`AGENTS.md`](AGENTS.md) first. The one write path for toolboxes is `Toolbox::Update` (`app/services/toolboxes/update.rb`). The web editor, MCP and WebMCP all go through it, and it records the dated history in `entry_changes`. Agent sources (`mcp`, `webmcp`) may run only `suggest` and `withdraw`. Every count on a page or in a tool comes from the shared read layer in `app/queries/` (`Audience`, `TeamRankings`, `PersonPicks`, `ModelLaunches`, `NumberOneHistory`, `Search`), read as the viewer.
