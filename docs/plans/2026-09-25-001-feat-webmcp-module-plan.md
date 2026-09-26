---
title: WebMCP Module - Plan
type: feat
date: 2026-09-25
artifact_contract: ce-unified-plan/v1
artifact_readiness: implementation-ready
product_contract_source: ce-plan-bootstrap
execution: code
---

# WebMCP Module - Plan

## Goal Capsule

- **Objective:** Ship an optional `webmcp` module: one server-side tool registry that feeds both an MCP server and WebMCP browser tools, so an agent driving a signed-in user's browser tab can call typed app tools through the page.
- **Authority:** Kieran's request ("Add WebMCP as a module to compound-stack-rails too! Look at Thinkroom"), then repository module/manifest/changelog conventions, then Thinkroom's shipped implementation (`app/frontend/lib/webmcp*.ts`, `app/services/agent_guide.rb`, `script/webmcp_check.mjs`).
- **Execution profile:** Ruby registry + JSON endpoint + shared Inertia prop, a React provider mounted in `inertia.tsx`, a `tool` generator, Minitest + Vitest coverage, module doc, manifest, 0.8.0 changelog entry.
- **Stop conditions:** Stop if the endpoint would need to skip CSRF or authenticate by anything other than the existing session cookie, or if the module grows into an MCP transport with its own credentials (OAuth/Bearer) — that is app-specific follow-up.
- **Tail ownership:** LFG owns review, commits, PR, and CI.

---

## Product Contract

### Summary

A template app exposes app capabilities as tools once, in `app/tools/`. `ToolRegistry` lists them. The same registry (a) builds an `MCP::Server` (official `mcp` gem) for any MCP transport the app mounts and (b) ships a WebMCP manifest as a shared Inertia prop to signed-in pages, where `WebmcpProvider` registers each tool on the browser's model context and executes calls through a session-authenticated, CSRF-protected JSON endpoint.

### What Thinkroom does, and what changes here

- Thinkroom registers tools with `document.modelContext.registerTool(tool, { signal })` (current W3C draft) and unregisters by aborting the signal; the stack keeps that and also falls back to the older `navigator.modelContext` surface (Chrome's first origin-trial builds), calling a returned `unregister()` / `unregisterTool(name)` when present.
- Thinkroom's manifest comes from `AgentGuide` and is shared as a page prop; the CLI help and agent guide read the same table. Here the single source is `ToolRegistry`, and the second consumer is an MCP server rather than a CLI.
- Thinkroom's tools call its anonymous Bearer API with `credentials: 'omit'` and an `X-Agent-Name` identity, because its writes are agent-attributed link-holder actions. A stack app's tools act as the signed-in user, so they go through the session cookie with a CSRF token (the user's explicit requirement), and only signed-in pages receive the manifest.
- Results keep Thinkroom's MCP-style envelope `{ content: [{ type: "text", text }], isError? }`, never thrown.

### Requirements

- R1. `ToolRegistry` is the only list of tools. Each tool is an `ApplicationTool` subclass declaring name, description, JSON-Schema input, and a read-only hint, and implementing `call` against `user` and `arguments`.
- R2. `ToolRegistry.mcp_server(user:)` returns an `MCP::Server` whose `tools/list` and `tools/call` match the WebMCP manifest and endpoint results for the same tool.
- R3. Signed-in Inertia pages receive `webmcp: { endpoint, tools }`; signed-out pages receive `webmcp: nil`.
- R4. `WebmcpProvider` registers every manifest tool when a model context exists and the manifest is non-null, and unregisters them all when the manifest becomes null (sign-out), changes, or the provider unmounts. No-op (and no console noise) without WebMCP. StrictMode-safe.
- R5. Feature detection: `document.modelContext` first, then `navigator.modelContext`; the object must have a callable `registerTool`. SSR-safe.
- R6. `POST /webmcp/tools/:name` requires a session (401 JSON otherwise, never a redirect), a valid CSRF token (422 JSON otherwise), returns 404 for unknown tools, 422 for invalid arguments or tool-raised `ApplicationTool::Error`, 200 `{ result }` on success. Rate limited.
- R7. The client sends `X-CSRF-Token` (from Inertia's `XSRF-TOKEN` cookie, falling back to the `csrf-token` meta tag), same-origin credentials, and aborts on either page teardown or the agent's per-call signal.
- R8. `bin/rails g tool Name` scaffolds a tool and its test and adds it to `ToolRegistry::TOOLS`.
- R9. Optional Chrome origin-trial meta tags from `WEBMCP_ORIGIN_TRIAL_TOKEN` (validated, one per origin), none when unset.
- R10. Module doc, registry row, manifest key, `AGENTS.md` enumeration + guidance, `CHANGELOG.md`, and a `0.8.0-001` agent-executable entry.

### Scope Boundaries

- No MCP HTTP transport or MCP-client credentials ship; the doc shows where one mounts.
- No declarative `<form toolname>` tools; no polyfill.
- The API stays small (`ApplicationTool`, `ToolRegistry`, `WebmcpProvider`, one endpoint) so `kieranklaassen/happyhappy` can adopt it later by copying the boundary.

### Key Technical Decisions

- KTD1. Registry is an explicit constant list, not `inherited`-hook discovery: Zeitwerk lazy-loads in development, so self-registration would miss unloaded tools.
- KTD2. The manifest travels as a shared Inertia prop (the stack's "Rails owns props" rule); only tool *execution* is a JSON endpoint, documented as the one sanctioned exception.
- KTD3. The provider sits above `<App>` and follows Inertia `navigate` events, so it sees sign-in/sign-out prop changes without a persistent layout.
- KTD4. Minimal argument validation in Ruby (required keys, no unknown keys, primitive types) instead of a JSON-Schema gem.

## Implementation Units

- U1. `app/tools/application_tool.rb`, `whoami_tool.rb`, `tool_registry.rb`; `mcp` gem. Tests: `test/tools/*`.
- U2. `WebmcpToolsController`, route, shared prop in `InertiaController`, origin-trial initializer + layout meta. Tests: `test/controllers/webmcp_tools_controller_test.rb`, prop test, origin-trial test.
- U3. `app/frontend/types/webmcp.d.ts`, `lib/webmcp.ts`, `lib/webmcp_provider.tsx`, mount in `inertia.tsx`, `SharedProps` typing. Tests: Vitest with stubbed `document.modelContext` and `navigator.modelContext`.
- U4. `lib/generators/tool/` generator + test.
- U5. Docs: `docs/modules/webmcp.md`, README registry row, `.template-manifest.yml` 0.8.0, `docs/changelog/0.8.0-001-add-webmcp-module.md`, `CHANGELOG.md`, `AGENTS.md`, `README.md`, `CONCEPTS.md`.

## Verification Contract

- `bin/rails test`, `bin/rubocop`, `bin/brakeman --no-pager`, `npm run check` green.
