import { afterEach, describe, expect, it, vi } from 'vitest'
import { installModelContext, removeModelContext } from '../test/model_context_stub'
import { callTool, csrfToken, getModelContext, registerTools, type WebmcpManifest } from './webmcp'

const manifest: WebmcpManifest = {
  endpoint: '/webmcp/tools',
  tools: [
    {
      name: 'get_my_toolbox',
      description: 'Returns the signed-in email.',
      inputSchema: { type: 'object', properties: {}, required: [] },
      annotations: { readOnlyHint: true, destructiveHint: false },
    },
  ],
}

const okResult = { content: [{ type: 'text', text: '{"email_address":"a@b.co"}' }], isError: false }

function stubFetch(status: number, body: unknown) {
  const fetchMock = vi.fn().mockResolvedValue(new Response(JSON.stringify(body), { status }))
  vi.stubGlobal('fetch', fetchMock)
  return fetchMock
}

function setCsrfMeta(token: string) {
  const meta = document.createElement('meta')
  meta.name = 'csrf-token'
  meta.content = token
  document.head.append(meta)
}

afterEach(() => {
  removeModelContext()
  vi.unstubAllGlobals()
  vi.restoreAllMocks()
  document.head.innerHTML = ''
  document.cookie = 'XSRF-TOKEN=; expires=Thu, 01 Jan 1970 00:00:00 GMT'
})

describe('getModelContext', () => {
  it('returns null without WebMCP', () => {
    expect(getModelContext()).toBeNull()
  })

  it('prefers document.modelContext (current draft)', () => {
    const stub = installModelContext('current')
    expect(getModelContext()).toBe(stub)
  })

  it('falls back to navigator.modelContext (early origin trial)', () => {
    const stub = installModelContext('legacy')
    expect(getModelContext()).toBe(stub)
  })

  it('ignores an object without a callable registerTool', () => {
    Object.defineProperty(document, 'modelContext', { value: { registerTool: 'nope' }, configurable: true })
    expect(getModelContext()).toBeNull()
  })
})

describe('csrfToken', () => {
  it('prefers the XSRF-TOKEN cookie Inertia refreshes on every response', () => {
    setCsrfMeta('from-meta')
    document.cookie = 'XSRF-TOKEN=from%2Bcookie'
    expect(csrfToken()).toBe('from+cookie')
  })

  it('falls back to the csrf-token meta tag', () => {
    setCsrfMeta('from-meta')
    expect(csrfToken()).toBe('from-meta')
  })
})

describe('callTool', () => {
  it('POSTs the arguments with the CSRF token and same-origin credentials', async () => {
    setCsrfMeta('token-123')
    const fetchMock = stubFetch(200, { result: okResult })

    const result = await callTool('/webmcp/tools', 'get_my_toolbox', { q: 1 })

    expect(result).toEqual(okResult)
    const [url, init] = fetchMock.mock.calls[0] as [string, RequestInit]
    expect(url).toBe('/webmcp/tools/get_my_toolbox')
    expect(init.method).toBe('POST')
    expect(init.credentials).toBe('same-origin')
    expect((init.headers as Record<string, string>)['X-CSRF-Token']).toBe('token-123')
    expect(JSON.parse(init.body as string)).toEqual({ arguments: { q: 1 } })
  })

  it('turns an HTTP error into an isError result carrying status and body', async () => {
    stubFetch(401, { error: 'Sign in' })
    const result = await callTool('/webmcp/tools', 'get_my_toolbox', {})
    expect(result.isError).toBe(true)
    expect(JSON.parse(result.content[0]!.text)).toEqual({ status: 401, error: 'Sign in' })
  })

  it('turns a network failure into an isError result instead of throwing', async () => {
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new TypeError('Failed to fetch')))
    const result = await callTool('/webmcp/tools', 'get_my_toolbox', {})
    expect(result.isError).toBe(true)
    expect(result.content[0]!.text).toContain('unreachable')
  })

  it('refuses an endpoint that is not a same-origin path, without fetching', async () => {
    const fetchMock = stubFetch(200, { result: okResult })
    const result = await callTool('//evil.example/tools', 'get_my_toolbox', {})
    expect(result.isError).toBe(true)
    expect(fetchMock).not.toHaveBeenCalled()
  })
})

describe('registerTools', () => {
  it('registers each tool with its schema and read-only hint, and aborting unregisters', async () => {
    const stub = installModelContext('current')
    const controller = new AbortController()

    registerTools(stub, manifest, controller.signal)
    const tool = stub.tools.get('get_my_toolbox')!
    expect(tool.description).toBe('Returns the signed-in email.')
    expect(tool.inputSchema).toEqual(manifest.tools[0]!.inputSchema)
    expect(tool.annotations).toEqual({ readOnlyHint: true })

    controller.abort()
    expect(stub.tools.size).toBe(0)
  })

  it('executes through the endpoint and returns the MCP result', async () => {
    const stub = installModelContext('current')
    stubFetch(200, { result: okResult })
    registerTools(stub, manifest, new AbortController().signal)

    await expect(stub.invoke('get_my_toolbox')).resolves.toEqual(okResult)
  })

  it("cancels the request when the agent aborts the call's own signal", async () => {
    const stub = installModelContext('current')
    vi.stubGlobal(
      'fetch',
      vi.fn(
        (_url: string, init: RequestInit) =>
          new Promise((_resolve, reject) =>
            init.signal!.addEventListener('abort', () => reject(new DOMException('aborted', 'AbortError'))),
          ),
      ),
    )
    registerTools(stub, manifest, new AbortController().signal)

    const call = new AbortController()
    const pending = stub.invoke('get_my_toolbox', {}, { signal: call.signal })
    call.abort()

    const result = (await pending) as { isError: boolean; content: [{ text: string }] }
    expect(result.isError).toBe(true)
    expect(result.content[0].text).toContain('cancelled')
  })

  it('unregisters through the returned handle on the legacy navigator surface', async () => {
    const stub = installModelContext('legacy')
    const controller = new AbortController()
    registerTools(stub, manifest, controller.signal)
    await Promise.resolve()
    expect(stub.tools.has('get_my_toolbox')).toBe(true)

    controller.abort()
    expect(stub.tools.size).toBe(0)
  })

  describe('reloading after a write', () => {
    const writeManifest: WebmcpManifest = {
      endpoint: '/webmcp/tools',
      tools: [
        { name: 'get_my_toolbox', description: 'Reads', inputSchema: { type: 'object' }, annotations: { readOnlyHint: true } },
        { name: 'suggest_picks', description: 'Suggests', inputSchema: { type: 'object' }, annotations: { readOnlyHint: false } },
        { name: 'no_hint', description: 'Says nothing about writes', inputSchema: { type: 'object' } },
      ],
    }

    it('calls onWrite once a tool that is not read-only succeeds, and returns its result unchanged', async () => {
      const stub = installModelContext('current')
      stubFetch(200, { result: okResult })
      const onWrite = vi.fn()
      registerTools(stub, writeManifest, new AbortController().signal, onWrite)

      await expect(stub.invoke('suggest_picks', { picks: [] })).resolves.toEqual(okResult)

      expect(onWrite).toHaveBeenCalledTimes(1)
    })

    it('does not call onWrite for a read-only tool', async () => {
      const stub = installModelContext('current')
      stubFetch(200, { result: okResult })
      const onWrite = vi.fn()
      registerTools(stub, writeManifest, new AbortController().signal, onWrite)

      await stub.invoke('get_my_toolbox')

      expect(onWrite).not.toHaveBeenCalled()
    })

    it('does not call onWrite when the call fails', async () => {
      const stub = installModelContext('current')
      stubFetch(422, { error: 'Bad arguments' })
      const onWrite = vi.fn()
      registerTools(stub, writeManifest, new AbortController().signal, onWrite)

      const result = (await stub.invoke('suggest_picks')) as { isError: boolean }

      expect(result.isError).toBe(true)
      expect(onWrite).not.toHaveBeenCalled()
    })

    it('treats a tool with no read-only hint as a write', async () => {
      const stub = installModelContext('current')
      stubFetch(200, { result: okResult })
      const onWrite = vi.fn()
      registerTools(stub, writeManifest, new AbortController().signal, onWrite)

      await stub.invoke('no_hint')

      expect(onWrite).toHaveBeenCalledTimes(1)
    })
  })

  it('warns on a duplicate name instead of throwing', async () => {
    const stub = installModelContext('current')
    const warn = vi.spyOn(console, 'warn').mockImplementation(() => {})
    registerTools(stub, manifest, new AbortController().signal)
    registerTools(stub, manifest, new AbortController().signal)
    await new Promise((resolve) => setTimeout(resolve, 0))

    expect(warn).toHaveBeenCalledTimes(1)
    expect(String(warn.mock.calls[0]?.[0])).toContain('get_my_toolbox')
  })
})
