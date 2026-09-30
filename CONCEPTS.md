# CONCEPTS

Shared vocabulary for this repo. When a term here is ambiguous in conversation,
this file is the tie-breaker. Keep entries short; link to module docs for depth.

- **Template** — compound-stack-rails, the app Toolbox started from at 0.8.0.
  Toolbox is a downstream app: it receives template upgrades as PRs and adds no
  changelog entries of its own.
- **Module** — an independently adoptable slice of the stack (auth, jobs, deploy,
  …). Each has a `docs/modules/<name>.md` boundary doc and a key in
  `.template-manifest.yml`.
- **Manifest** — `.template-manifest.yml` in a downstream app: the template
  version it is on plus the modules it has adopted (and at which version).
- **Changelog entry** — a file under `docs/changelog/` written as **imperative
  upgrade instructions an agent executes against a downstream app**, not human
  release notes.
- **Upgrade agent** — an agent pointed at a downstream app that reads the
  changelog against the app's manifest, applies what is owed, and opens a PR.
- **Shared props** — data every Inertia page receives via `InertiaController`
  (flash, locale, feedback-capture gate, WebMCP tool manifest). A page reads them; it does not fetch.
- **Tool registry** — `ToolRegistry` (`app/tools/`): the one list of agent tools.
  It feeds both the MCP server and the WebMCP browser tools, so the two cannot
  drift. See [docs/modules/webmcp.md](docs/modules/webmcp.md).
- **WebMCP** — the browser API (`document.modelContext.registerTool`) through which a
  page offers typed tools to an agent driving the tab. Here it is signed-in
  only, and each call goes through `POST /webmcp/tools/:name`.
- **Born-complete** — a fresh clone of the template already lists every module in
  its manifest, so it starts fully adopted.
- **Kind of work** — one of the 11 areas a person ranks tools for (coding, writing,
  research, and so on). Stored as a `Category`.
- **Pick** — one ranked slot in a kind of work: a tool, an optional model, an
  optional context size (`200k`, `1m`) and an optional effort. A person keeps up
  to three per kind, at ranks 1 to 3.
- **Suggestion** — a pick an agent proposed over MCP or WebMCP. It lives in
  `pick_suggestions`, is visible only to its owner, and becomes a pick only when
  the owner confirms it on the web.
- **Visibility** — who may open a person's page: `only_me` (shown as Private), `team`
  or `link`. New members start at `link` when they claim a handle. It decides who is
  named, not who is counted: a private Every team member still counts anonymously.
  Every span in which a person shared is kept as a visibility period.
- **Audience** — who a viewer's page is about. Its counted people are every onboarded
  Every team member (for the team view) and every "N of M" is taken over them; its named
  people are the ones the viewer may open, the only people ever named, linked or found.
- **Vibe Check history** — what an Every Vibe Check article quoted a member using, written
  into their dated history from `config/vibe_checks.yml` so "What we used before" reaches back
  before Toolbox. It holds until their next Vibe Check, their own first change, or 90 days.
- **Launch** — a model with a release date and a Vibe Check link, shown in
  "Latest model launches" on Home.
- **Mark** — the light tile that stands for a tool (square) or a model (round):
  its real single-colour logo when the catalog has one, else the first letter of
  its name in the serif face.
- **Every dark** — the app's design system: a near-black page, #111111 panels and
  three sparing accents. See [docs/modules/frontend.md](docs/modules/frontend.md).
