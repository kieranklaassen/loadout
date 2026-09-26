import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { registerServiceWorker, resetServiceWorkerRegistrationForTests } from './pwa'

// jsdom has no navigator.serviceWorker, so each test installs (or omits) a stub.
function stubServiceWorker(register: ReturnType<typeof vi.fn>) {
  Object.defineProperty(navigator, 'serviceWorker', {
    value: { register },
    configurable: true,
  })
}

function removeServiceWorker() {
  // Cast: the stubbed property is configurable, so delete is legal here.
  delete (navigator as { serviceWorker?: unknown }).serviceWorker
}

describe('registerServiceWorker', () => {
  beforeEach(() => {
    resetServiceWorkerRegistrationForTests()
  })

  afterEach(() => {
    removeServiceWorker()
    vi.restoreAllMocks()
  })

  it('registers /service-worker at scope / exactly once', async () => {
    const register = vi.fn().mockResolvedValue({})
    stubServiceWorker(register)

    await registerServiceWorker()

    expect(register).toHaveBeenCalledTimes(1)
    expect(register).toHaveBeenCalledWith('/service-worker', { scope: '/' })
  })

  it('is a no-op when the browser has no serviceWorker support', async () => {
    removeServiceWorker()

    await expect(registerServiceWorker()).resolves.toBeUndefined()
  })

  it('swallows registration failures with a warning instead of throwing', async () => {
    const register = vi.fn().mockRejectedValue(new Error('SecurityError'))
    stubServiceWorker(register)
    const warn = vi.spyOn(console, 'warn').mockImplementation(() => {})

    await expect(registerServiceWorker()).resolves.toBeUndefined()

    expect(warn).toHaveBeenCalledTimes(1)
    expect(String(warn.mock.calls[0]?.[1])).toContain('SecurityError')
  })

  it('does not register twice within one page lifecycle', async () => {
    const register = vi.fn().mockResolvedValue({})
    stubServiceWorker(register)

    await registerServiceWorker()
    await registerServiceWorker()

    expect(register).toHaveBeenCalledTimes(1)
  })
})
