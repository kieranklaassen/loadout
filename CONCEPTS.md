# CONCEPTS

Shared vocabulary for this repo. When a term here is ambiguous in conversation,
this file is the tie-breaker. Keep entries short; link to module docs for depth.

- **Template** — this repo: the canonical Rails app the fleet converges on. New
  apps clone it; existing apps adopt modules from it à la carte.
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
