// Ambient types for WebMCP (W3C Web Machine Learning CG draft):
// https://webmachinelearning.github.io/webmcp/
//
// The current draft puts the model context on `document.modelContext` and
// unregisters a tool by aborting the signal passed to `registerTool`. Chrome's
// first origin-trial builds exposed `navigator.modelContext` and returned an
// `{ unregister() }` handle (or offered `unregisterTool(name)`); both shapes are
// declared so `getModelContext()` in lib/webmcp.ts can support either. Written
// by hand to keep an MCP package out of the bundle while the spec moves.

interface ModelContextToolAnnotations {
  readOnlyHint?: boolean
  untrustedContentHint?: boolean
}

interface ModelContextTool {
  name: string
  description: string
  inputSchema?: object
  annotations?: ModelContextToolAnnotations
  /** A rejection reaches the agent as an opaque error, so results carry failures as data. */
  execute: (
    input: Record<string, unknown>,
    options?: { readonly signal?: AbortSignal },
  ) => unknown | Promise<unknown>
}

interface ModelContextRegistration {
  unregister?: () => void
}

interface ModelContext {
  registerTool(
    tool: ModelContextTool,
    options?: { signal?: AbortSignal },
  ): void | ModelContextRegistration | Promise<void | ModelContextRegistration>
  /** Legacy navigator.modelContext surface only. */
  unregisterTool?: (name: string) => void
}

interface Document {
  readonly modelContext?: ModelContext
}

interface Navigator {
  readonly modelContext?: ModelContext
}
