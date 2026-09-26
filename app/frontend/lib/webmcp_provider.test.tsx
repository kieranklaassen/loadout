import { act, render } from '@testing-library/react'
import { StrictMode } from 'react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { installModelContext, removeModelContext } from '../test/model_context_stub'
import type { WebmcpManifest } from './webmcp'
import WebmcpProvider from './webmcp_provider'

type NavigateListener = (event: { detail: { page: { props: Record<string, unknown> } } }) => void
const navigateListeners = new Set<NavigateListener>()

vi.mock('@inertiajs/react', () => ({
  router: {
    on: (type: string, listener: NavigateListener) => {
      if (type !== 'navigate') return () => {}
      navigateListeners.add(listener)
      return () => navigateListeners.delete(listener)
    },
  },
}))

function navigate(props: Record<string, unknown>) {
  act(() => navigateListeners.forEach((listener) => listener({ detail: { page: { props } } })))
}

const manifest: WebmcpManifest = {
  endpoint: '/webmcp/tools',
  tools: [
    { name: 'whoami', description: 'Who am I', inputSchema: { type: 'object' }, annotations: { readOnlyHint: true } },
    { name: 'list_notes', description: 'List notes', inputSchema: { type: 'object' } },
  ],
}

describe('WebmcpProvider', () => {
  beforeEach(() => navigateListeners.clear())
  afterEach(() => removeModelContext())

  it('registers every tool for a signed-in user, surviving StrictMode double effects', async () => {
    const stub = installModelContext()
    const register = vi.spyOn(stub, 'registerTool')

    render(
      <StrictMode>
        <WebmcpProvider initialManifest={manifest}>
          <p>page</p>
        </WebmcpProvider>
      </StrictMode>,
    )

    expect([...stub.tools.keys()].sort()).toEqual(['list_notes', 'whoami'])
    // StrictMode mounts twice; the first registration is aborted before the second.
    expect(register).toHaveBeenCalledTimes(4)
  })

  it('registers nothing while signed out', () => {
    const stub = installModelContext()
    render(<WebmcpProvider initialManifest={null}>page</WebmcpProvider>)
    expect(stub.tools.size).toBe(0)
  })

  it('registers on sign-in and unregisters on sign-out across Inertia visits', () => {
    const stub = installModelContext()
    render(<WebmcpProvider initialManifest={null}>page</WebmcpProvider>)

    navigate({ webmcp: manifest })
    expect(stub.tools.size).toBe(2)

    navigate({ webmcp: null })
    expect(stub.tools.size).toBe(0)
  })

  it('keeps the registration when a visit re-sends an equal manifest', () => {
    const stub = installModelContext()
    const register = vi.spyOn(stub, 'registerTool')
    render(<WebmcpProvider initialManifest={manifest}>page</WebmcpProvider>)

    navigate({ webmcp: structuredClone(manifest) })
    expect(register).toHaveBeenCalledTimes(2)
    expect(stub.tools.size).toBe(2)
  })

  it('unregisters everything on unmount', () => {
    const stub = installModelContext()
    const { unmount } = render(<WebmcpProvider initialManifest={manifest}>page</WebmcpProvider>)
    unmount()
    expect(stub.tools.size).toBe(0)
  })

  it('renders children and stays silent without WebMCP', () => {
    const warn = vi.spyOn(console, 'warn').mockImplementation(() => {})
    const { getByText } = render(<WebmcpProvider initialManifest={manifest}>page</WebmcpProvider>)
    expect(getByText('page')).toBeInTheDocument()
    expect(warn).not.toHaveBeenCalled()
  })
})
