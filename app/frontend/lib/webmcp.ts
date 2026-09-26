// WebMCP page side (docs/modules/webmcp.md): feature detection, the manifest
// shape `ToolRegistry.manifest` ships as the `webmcp` shared prop, tool
// registration, and the CSRF-protected call to `POST /webmcp/tools/:name`.

/** One entry of `ToolRegistry.manifest` — the MCP `tools/list` tool shape. */
export interface WebmcpTool {
  name: string
  description: string
  inputSchema: Record<string, unknown>
  annotations?: {
    readOnlyHint?: boolean
    destructiveHint?: boolean
    idempotentHint?: boolean
    openWorldHint?: boolean
  }
}

export interface WebmcpManifest {
  /** Same-origin path; a tool runs at `${endpoint}/${name}`. */
  endpoint: string
  tools: WebmcpTool[]
}

/** MCP `CallToolResult`: what both the MCP server and the endpoint return. */
export interface WebmcpResult {
  content: Array<{ type: 'text'; text: string }>
  isError?: boolean
}

/**
 * The browser's model context, or null when WebMCP is unavailable (every
 * browser but a WebMCP-enabled Chrome, and SSR). Prefers the current draft's
 * `document.modelContext`, falls back to the older `navigator.modelContext`,
 * and requires a callable `registerTool` so a partial object is ignored.
 */
export function getModelContext(): ModelContext | null {
  if (typeof document === 'undefined' || typeof navigator === 'undefined') return null
  for (const context of [document.modelContext, navigator.modelContext]) {
    if (context && typeof context.registerTool === 'function') return context
  }
  return null
}

/**
 * Inertia keeps a fresh `XSRF-TOKEN` cookie on every response; the layout's
 * `csrf-token` meta is the fallback before the first Inertia round trip.
 */
export function csrfToken(): string | null {
  const cookie = document.cookie.split('; ').find((entry) => entry.startsWith('XSRF-TOKEN='))
  if (cookie) return decodeURIComponent(cookie.slice('XSRF-TOKEN='.length))
  return document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content ?? null
}

export function errorResult(value: unknown): WebmcpResult {
  const text = typeof value === 'string' ? value : JSON.stringify(value)
  return { content: [{ type: 'text', text }], isError: true }
}

/**
 * Runs a tool through the session-authenticated endpoint. Never throws and
 * never returns undefined: the spec turns a rejected `execute` into an opaque
 * error, so every failure comes back as an `isError` result.
 */
export async function callTool(
  endpoint: string,
  name: string,
  args: Record<string, unknown>,
  signal?: AbortSignal,
): Promise<WebmcpResult> {
  if (!endpoint.startsWith('/') || endpoint.startsWith('//')) {
    return errorResult({ error: `refused: ${endpoint} is not a same-origin path` })
  }

  const headers: Record<string, string> = {
    Accept: 'application/json',
    'Content-Type': 'application/json',
  }
  const token = csrfToken()
  if (token) headers['X-CSRF-Token'] = token

  try {
    const response = await fetch(`${endpoint}/${encodeURIComponent(name)}`, {
      method: 'POST',
      credentials: 'same-origin',
      headers,
      body: JSON.stringify({ arguments: args ?? {} }),
      signal,
    })
    const body: unknown = await response.json().catch(() => null)
    if (response.ok && isResult(body)) return body.result
    return errorResult({ status: response.status, ...(isObject(body) ? body : {}) })
  } catch (error) {
    if (signal?.aborted || isAbortError(error)) return errorResult({ error: 'cancelled' })
    return errorResult({ error: 'unreachable', detail: error instanceof Error ? error.message : String(error) })
  }
}

/**
 * Registers every manifest tool on `context`; aborting `signal` unregisters
 * them all and cancels in-flight calls. Registration failures are logged, not
 * thrown: AbortError is the expected result of React StrictMode's immediate
 * cleanup, and a duplicate name must not take the page down.
 */
export function registerTools(context: ModelContext, manifest: WebmcpManifest, signal: AbortSignal): void {
  for (const tool of manifest.tools) {
    const definition: ModelContextTool = {
      name: tool.name,
      description: tool.description,
      inputSchema: tool.inputSchema,
      annotations: { readOnlyHint: tool.annotations?.readOnlyHint ?? false },
      execute: (input, options) => {
        const callSignal = options?.signal ? AbortSignal.any([signal, options.signal]) : signal
        return callTool(manifest.endpoint, tool.name, input ?? {}, callSignal)
      },
    }

    try {
      Promise.resolve(context.registerTool(definition, { signal }))
        .then((registration) => onAbort(signal, () => unregisterLegacy(context, tool.name, registration)))
        .catch((error: unknown) => reportRegistrationError(tool.name, error))
    } catch (error) {
      reportRegistrationError(tool.name, error)
    }
  }
}

function unregisterLegacy(context: ModelContext, name: string, registration: void | ModelContextRegistration): void {
  try {
    if (registration && typeof registration.unregister === 'function') registration.unregister()
    else if (typeof context.unregisterTool === 'function') context.unregisterTool(name)
  } catch {
    // Already gone: the current draft unregisters through the signal itself.
  }
}

function onAbort(signal: AbortSignal, callback: () => void): void {
  if (signal.aborted) callback()
  else signal.addEventListener('abort', callback, { once: true })
}

function reportRegistrationError(name: string, error: unknown): void {
  if (isAbortError(error)) return
  console.warn(`[webmcp] failed to register ${name}: ${error instanceof Error ? error.message : String(error)}`)
}

// DOMException is not an Error subclass in every runtime, so match on the name.
function isAbortError(error: unknown): boolean {
  return isObject(error) && error.name === 'AbortError'
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
}

function isResult(value: unknown): value is { result: WebmcpResult } {
  return isObject(value) && isObject(value.result) && Array.isArray(value.result.content)
}
