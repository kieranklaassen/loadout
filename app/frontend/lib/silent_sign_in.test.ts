import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { resetSilentSignInForTests, SILENT_TRIED_COOKIE, startSilentSignIn } from './silent_sign_in'

const reload = vi.hoisted(() => vi.fn())

vi.mock('@inertiajs/react', () => ({ router: { reload } }))

const PATH = '/session/silent'

// jsdom lets a test say what the document reports, one property at a time.
function report(property: 'visibilityState' | 'readyState', value: string) {
  Object.defineProperty(document, property, { configurable: true, get: () => value })
}

function show() {
  report('visibilityState', 'visible')
  document.dispatchEvent(new Event('visibilitychange'))
}

function frames() {
  return [...document.querySelectorAll('iframe')]
}

function theFrame() {
  const [frame] = frames()
  if (!frame) throw new Error('no frame was appended')
  return frame
}

function marker() {
  return document.cookie.split('; ').find((pair) => pair.startsWith(`${SILENT_TRIED_COOKIE}=`)) ?? null
}

// The frame ends on the tiny page: a document whose body says how it went.
function answer(frame: HTMLIFrameElement, outcome: string) {
  const page = document.implementation.createHTMLDocument()
  page.body.dataset.silentSignIn = outcome
  Object.defineProperty(frame, 'contentDocument', { configurable: true, get: () => page })
  frame.dispatchEvent(new Event('load'))
}

describe('startSilentSignIn', () => {
  beforeEach(() => {
    vi.useFakeTimers()
    resetSilentSignInForTests()
    reload.mockReset()
    report('visibilityState', 'visible')
    report('readyState', 'complete')
  })

  afterEach(() => {
    frames().forEach((frame) => frame.remove())
    document.cookie = `${SILENT_TRIED_COOKIE}=; max-age=0; path=/`
    // Drop the reports, so the document answers for itself again.
    delete (document as { visibilityState?: unknown }).visibilityState
    delete (document as { readyState?: unknown }).readyState
    vi.unstubAllGlobals()
    vi.restoreAllMocks()
    vi.useRealTimers()
  })

  it('does nothing when no attempt is due', () => {
    startSilentSignIn(null)

    expect(frames()).toHaveLength(0)
    expect(marker()).toBeNull()
  })

  it('sets the marker and appends one hidden frame at the path', () => {
    const written = vi.spyOn(document, 'cookie', 'set')

    startSilentSignIn(PATH)

    expect(written).toHaveBeenCalledWith(`every_silent_tried=asking; max-age=600; path=/; SameSite=Lax`)
    expect(marker()).toBe(`${SILENT_TRIED_COOKIE}=asking`)
    expect(frames()).toHaveLength(1)

    const frame = theFrame()
    expect(frame.getAttribute('src')).toBe(PATH)
    expect(frame.hidden).toBe(true)
    expect(frame.getAttribute('aria-hidden')).toBe('true')
    expect(frame.getAttribute('tabindex')).toBe('-1')
    expect(frame.title).not.toBe('')
    expect(frame.parentElement).toBe(document.body)
  })

  it('marks the cookie Secure on https', () => {
    vi.stubGlobal('location', { protocol: 'https:' })
    const written = vi.spyOn(document, 'cookie', 'set')

    startSilentSignIn(PATH)

    expect(written).toHaveBeenCalledWith(`every_silent_tried=asking; max-age=600; path=/; SameSite=Lax; Secure`)
  })

  it('appends one frame when called twice', () => {
    startSilentSignIn(PATH)
    startSilentSignIn(PATH)

    expect(frames()).toHaveLength(1)
  })

  it('does nothing inside a frame', () => {
    vi.stubGlobal('top', {})

    startSilentSignIn(PATH)

    expect(frames()).toHaveLength(0)
    expect(marker()).toBeNull()
  })

  it('does not frame when the cookie cannot be read back', () => {
    vi.spyOn(document, 'cookie', 'set').mockImplementation(() => {})

    startSilentSignIn(PATH)

    expect(frames()).toHaveLength(0)
  })

  it('waits for the window to load', () => {
    report('readyState', 'interactive')

    startSilentSignIn(PATH)
    expect(frames()).toHaveLength(0)
    expect(marker()).toBeNull()

    window.dispatchEvent(new Event('load'))
    expect(frames()).toHaveLength(1)
  })

  it('waits for a hidden tab to be shown, then frames once', () => {
    report('visibilityState', 'hidden')

    startSilentSignIn(PATH)
    expect(frames()).toHaveLength(0)
    expect(marker()).toBeNull()

    show()
    show()
    expect(frames()).toHaveLength(1)
  })

  it('leaves the marker alone when another tab set it before this one was shown', () => {
    report('visibilityState', 'hidden')
    startSilentSignIn(PATH)
    document.cookie = `${SILENT_TRIED_COOKIE}=declined; path=/`

    show()

    expect(frames()).toHaveLength(0)
    expect(marker()).toBe(`${SILENT_TRIED_COOKIE}=declined`)
  })

  it('removes the frame and reloads the props once when Every signed the visitor in', () => {
    startSilentSignIn(PATH)
    const frame = theFrame()

    answer(frame, 'signed_in')
    frame.dispatchEvent(new Event('load'))
    vi.advanceTimersByTime(10_000)

    expect(frames()).toHaveLength(0)
    expect(reload).toHaveBeenCalledTimes(1)
  })

  it('removes the frame and reloads nothing when Every said no', () => {
    startSilentSignIn(PATH)

    answer(theFrame(), 'signed_out')

    expect(frames()).toHaveLength(0)
    expect(reload).not.toHaveBeenCalled()
  })

  it('counts a frame it cannot read as a no', () => {
    startSilentSignIn(PATH)
    const frame = theFrame()
    Object.defineProperty(frame, 'contentDocument', {
      configurable: true,
      get: () => {
        throw new DOMException('Blocked a frame with origin', 'SecurityError')
      },
    })

    expect(() => frame.dispatchEvent(new Event('load'))).not.toThrow()

    expect(frames()).toHaveLength(0)
    expect(reload).not.toHaveBeenCalled()
  })

  it('gives up after ten seconds without an answer', () => {
    startSilentSignIn(PATH)

    vi.advanceTimersByTime(9_999)
    expect(frames()).toHaveLength(1)

    vi.advanceTimersByTime(1)
    expect(frames()).toHaveLength(0)
    expect(reload).not.toHaveBeenCalled()
  })

  it('reloads so that a failed reload opens no error dialog', () => {
    startSilentSignIn(PATH)
    answer(theFrame(), 'signed_in')

    const options = reload.mock.calls[0]?.[0]
    // A page that is not Inertia's (a 500, a proxy's error) would open the dialog.
    expect(options.onHttpException({ status: 500, headers: {}, data: '<h1>Error</h1>' })).toBe(false)
    expect(options.onNetworkError(new Error('offline'))).toBe(false)
  })

  it("lets the reload show Toolbox's own 404 page as the member", () => {
    startSilentSignIn(PATH)
    answer(theFrame(), 'signed_in')

    const options = reload.mock.calls[0]?.[0]
    const notFound = { status: 404, headers: { 'x-inertia': 'true' }, data: { component: 'errors/not_found' } }
    expect(options.onHttpException(notFound)).not.toBe(false)
  })

  it('surfaces nothing when the reload throws', () => {
    reload.mockImplementation(() => {
      throw new Error('no page to reload')
    })
    startSilentSignIn(PATH)
    const frame = theFrame()

    expect(() => answer(frame, 'signed_in')).not.toThrow()
    expect(frames()).toHaveLength(0)
  })
})
