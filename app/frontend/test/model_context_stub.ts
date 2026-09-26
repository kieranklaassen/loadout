// A spec-shaped WebMCP model context for tests: jsdom (and CI's Chromium) has
// none. `current` follows the W3C draft — `document.modelContext`, AbortSignal
// unregistration, InvalidStateError on a duplicate name. `legacy` follows
// Chrome's first origin-trial builds — `navigator.modelContext` with an
// `{ unregister() }` handle and no signal support.

export interface ModelContextStub extends ModelContext {
  tools: Map<string, ModelContextTool>
  /** Calls a registered tool's `execute` the way a browser agent would. */
  invoke(name: string, input?: Record<string, unknown>, options?: { signal?: AbortSignal }): Promise<unknown>
}

export function installModelContext(flavor: 'current' | 'legacy' = 'current'): ModelContextStub {
  const tools = new Map<string, ModelContextTool>()

  const stub: ModelContextStub = {
    tools,
    registerTool(tool, options) {
      if (tools.has(tool.name)) {
        return Promise.reject(new DOMException(`duplicate tool name: ${tool.name}`, 'InvalidStateError'))
      }
      if (flavor === 'legacy') {
        tools.set(tool.name, tool)
        return { unregister: () => tools.delete(tool.name) }
      }
      const signal = options?.signal
      if (signal?.aborted) return Promise.reject(new DOMException('aborted', 'AbortError'))
      tools.set(tool.name, tool)
      signal?.addEventListener('abort', () => tools.delete(tool.name), { once: true })
      return Promise.resolve()
    },
    async invoke(name, input = {}, options = {}) {
      const tool = tools.get(name)
      if (!tool) throw new Error(`no registered tool named ${name}`)
      return tool.execute(input, options)
    },
  }

  Object.defineProperty(flavor === 'legacy' ? navigator : document, 'modelContext', {
    value: stub,
    configurable: true,
  })
  return stub
}

export function removeModelContext(): void {
  delete (document as { modelContext?: unknown }).modelContext
  delete (navigator as { modelContext?: unknown }).modelContext
}
