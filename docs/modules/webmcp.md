# Module: webmcp

One registry of agent tools, served two ways: to MCP clients through an
`MCP::Server`, and to browser agents through [WebMCP](https://webmachinelearning.github.io/webmcp/),
which lets a page register typed tools on the browser's model context so an
agent driving a signed-in user's tab can call them.

## What this module is

- **Tools are defined once**, in `app/tools/`, as `ApplicationTool` subclasses.
  `ApplicationTool < MCP::Tool` (the official [`mcp`](https://github.com/modelcontextprotocol/ruby-sdk)
  gem), so the SDK's DSL declares each tool: `tool_name`, `description`,
  `input_schema` (JSON Schema, validated by the SDK), `annotations`. A tool
  implements `#call`, acts as `user`, reads `arguments` (symbol keys), and
  returns a String or anything JSON-serializable; raising
  `ApplicationTool::Error` returns an `isError` result the agent can read.
- **`ToolRegistry`** is the one list (`ToolRegistry::TOOLS`). Both surfaces read it:
  - `ToolRegistry.mcp_server(user:)` → an `MCP::Server` for whatever MCP
    transport the app mounts.
  - `ToolRegistry.manifest` → the `webmcp` shared Inertia prop
    (`{ endpoint, tools: [{ name, description, inputSchema, annotations }] }`),
    present only when signed in, `nil` otherwise.
  - `ToolRegistry.call(name, arguments:, user:)` → runs a tool through that same
    `MCP::Server` (`tools/call`), so a browser call and an MCP call return the
    identical `CallToolResult`.
- **`POST /webmcp/tools/:name`** (`WebmcpToolsController`) executes a tool for
  the browser. Session cookie auth plus Rails CSRF. It returns JSON and never
  redirects: `200 { result }` (a tool error is still 200, with `isError: true`),
  `400` for a malformed body, `401` with no session, `404` for an unknown tool,
  `422` for a bad CSRF token, and `429` after 60 calls a minute per user. It is the one sanctioned
  JSON endpoint beside Inertia pages: definitions still travel as props, but
  the browser calls a tool long after the page rendered.
- **`WebmcpProvider`** (mounted above `<App>` in `inertia.tsx`) follows every
  Inertia visit's `webmcp` prop. On sign-in it registers each tool; on sign-out
  (prop → `null`), on a changed manifest, or on unmount it unregisters them all.
  An equal manifest on the next visit does not re-register, and StrictMode's
  double effect is safe.
- **Feature detection** (`getModelContext()` in `lib/webmcp.ts`): the current
  draft's `document.modelContext` first, then the early origin trial's
  `navigator.modelContext`, and only if `registerTool` is callable. Without it
  (every other browser, SSR) nothing runs and nothing logs. Unregistration
  aborts the `AbortSignal` passed to `registerTool`, and also calls a returned
  `unregister()` or `unregisterTool(name)` on the legacy surface.
- **Results are data, never exceptions**: `execute` always resolves to an MCP
  `{ content: [{ type: "text", text }], isError? }`. That covers HTTP errors, network failure,
  and cancellation (the agent's per-call signal and page teardown both abort
  the fetch).
- **Origin trial**: `WEBMCP_ORIGIN_TRIAL_TOKEN` (one public, origin-bound token
  per production host, whitespace- or comma-separated) becomes
  `<meta http-equiv="origin-trial">` tags; none when unset.

This design follows Thinkroom's WebMCP (`kieranklaassen/thinkroom`). What
carries over: page-side registration with an `AbortSignal`, results carried as
data, and the manifest arriving as a server-built prop. What differs: Thinkroom's
tools are anonymous link-holder actions against a Bearer API, so they send no
cookies and name the agent in a header. A stack app's tools act as the
signed-in user, so they use the session and a CSRF token.

## Files (the module boundary)

- `Gemfile`: `gem "mcp", "~> 1.6"`
- `app/tools/application_tool.rb`, `app/tools/tool_registry.rb`,
  `app/tools/whoami_tool.rb` (example; replace it)
- `app/controllers/webmcp_tools_controller.rb`
- `config/routes.rb`: the `webmcp_tool` route (`post "webmcp/tools/:name"`)
- `app/controllers/inertia_controller.rb`: the `webmcp` `inertia_share`
- `config/initializers/webmcp.rb`, the origin-trial `<meta>` loop in
  `app/views/layouts/application.html.erb`, and `WEBMCP_ORIGIN_TRIAL_TOKEN` in
  `config/deploy.yml`
- `app/frontend/lib/webmcp.ts`, `app/frontend/lib/webmcp_provider.tsx`,
  `app/frontend/types/webmcp.d.ts`, the `WebmcpProvider` wrapper in
  `app/frontend/entrypoints/inertia.tsx`
- `lib/generators/tool/` (`bin/rails g tool Name`) and `generators` in
  `config.autoload_lib(ignore:)` in `config/application.rb`
- Tests: `test/tools/`, `test/controllers/webmcp_tools_controller_test.rb`,
  `test/integration/webmcp_test.rb`, `test/generators/tool_generator_test.rb`,
  `app/frontend/lib/webmcp.test.ts`, `app/frontend/lib/webmcp_provider.test.tsx`,
  `app/frontend/test/model_context_stub.ts`

Depends on **auth** (`Current.session`, `Authentication`) and **frontend**
(Inertia shared props, `inertia.tsx`, layout).

## Adding a tool

```sh
bin/rails g tool SearchNotes
```

This creates `app/tools/search_notes_tool.rb` and `test/tools/search_notes_tool_test.rb`,
and adds `SearchNotesTool` to `ToolRegistry::TOOLS`. Then:

1. Write the `description` for the agent: what the tool does, for whom, and what it returns.
2. Declare `input_schema` properties. Keep `additionalProperties: false` so a
   typo fails validation instead of being ignored.
3. Set `annotations`: `read_only_hint: true` only for tools that never write;
   review `destructive_hint` for tools that do.
4. Implement `#call` and scope every query to `user`. Tools run with the user's authority.
5. Make the generated test pass.

The registry test fails if a tool in `app/tools/` is missing from `TOOLS`, or if
a name falls outside the WebMCP/MCP alphabet (`[A-Za-z0-9_.-]`, up to 128 characters).

## Serving the same tools over MCP

The module ships the server, not a transport, because MCP clients need their
own credentials (OAuth or tokens), and those are app-specific. Once the app
can resolve a user from a request, mount one:

```ruby
# app/controllers/mcp_controller.rb — sketch; authenticate before this runs
class McpController < ActionController::API
  def create
    server = ToolRegistry.mcp_server(user: user_from_bearer_token)
    render json: server.handle_json(request.raw_post)
  end
end
```

## Adopt into an existing app

1. Add `gem "mcp", "~> 1.6"` and `bundle install`.
2. Copy `app/tools/` (`application_tool.rb`, `tool_registry.rb`, `whoami_tool.rb`)
   and `app/controllers/webmcp_tools_controller.rb`. If the app's session
   concern differs from the Rails 8 generator's `Authentication`, adapt
   `request_authentication` (must render 401 JSON) and `Current.session.user`.
3. Add the route: `post "webmcp/tools/:name" => "webmcp_tools#create", as: :webmcp_tool, constraints: { name: /[A-Za-z0-9_.\-]{1,128}/ }, defaults: { format: :json }`.
4. Share the manifest on the Inertia base controller:
   `inertia_share webmcp: -> { ToolRegistry.manifest if authenticated? }`.
5. Copy `app/frontend/lib/webmcp.ts`, `webmcp_provider.tsx`, and
   `app/frontend/types/webmcp.d.ts`, then wrap the app in `inertia.tsx`:
   `<WebmcpProvider initialManifest={initialPage.props.webmcp ?? null}><App {...props} /></WebmcpProvider>`.
   The layout must emit `csrf_meta_tags` (Inertia's `XSRF-TOKEN` cookie is used
   first when present).
6. Optional: copy `config/initializers/webmcp.rb`, the origin-trial `<meta>`
   loop in the layout, and the `WEBMCP_ORIGIN_TRIAL_TOKEN` line in `config/deploy.yml`.
7. Copy `lib/generators/tool/` and add `generators` to
   `config.autoload_lib(ignore: ...)`.
8. Copy the tests listed in the boundary. Run the verification below, then add
   `webmcp: "<template_version>"` to `.template-manifest.yml`.

## Verify adoption

- `bin/rails test test/tools test/controllers/webmcp_tools_controller_test.rb test/integration/webmcp_test.rb test/generators/tool_generator_test.rb`
  and `npm run check` are green.
- In Chrome with `chrome://flags/#enable-webmcp-testing` (or on an origin with
  a trial token), sign in: DevTools → Application → WebMCP lists `whoami`, and
  running it returns your email. Sign out and the list is empty.
- Signed out, `curl -X POST localhost:<port>/webmcp/tools/whoami` answers
  `401` JSON.

## Gotchas

- **Every tool is a signed-in user action.** The browser agent calls a tool
  with the user's full session authority, and WebMCP has no confirmation step.
  Keep destructive actions out of the registry, or require an argument that
  names the target explicitly, until the product decides how agent actions
  are confirmed.
- **Tool output can reach the model as instructions.** If a tool returns text
  other users wrote (comments, documents), say so in the description so the
  agent treats it as data.
- **Keep names stable.** Agents and MCP clients cache tool names. Rename a tool
  by adding the new one and removing the old one in a later release.
- **The spec is still moving.** The draft moved the model context from `navigator` to
  `document` and dropped `provideContext`/`unregisterTool`. `lib/webmcp.ts` and
  `types/webmcp.d.ts` are the only files that know the browser surface.
- **CI has no WebMCP browser.** Tests use `app/frontend/test/model_context_stub.ts`,
  which installs a spec-shaped `document.modelContext` (or the legacy
  `navigator.modelContext`) that honors the abort signal and rejects duplicate
  names the way Chrome does.
