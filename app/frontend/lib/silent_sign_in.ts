// Automatic sign-in for a visitor whose browser is signed in to every.to.
//
// A signed-out page carries `silent_sign_in_path` when an attempt is due. This
// helper asks once, in a hidden frame: the frame goes to that path, Rails sends
// it on to Every, and whatever Every answers the frame ends on a tiny page of
// Toolbox's whose body says `signed_in` or `signed_out`. A visitor Every does
// not know sees nothing. It is started from the browser entrypoint and never
// from the server render, so a signed-out page's HTML stays as it was.

import { router } from '@inertiajs/react'

// The other half is EverySilentSignIn::TRIED_COOKIE. Any value means an attempt
// was made not long ago, by this tab or another, and no new one starts.
export const SILENT_TRIED_COOKIE = 'every_silent_tried'

// The value this side sets (EverySilentSignIn::ASKING), for as long as the
// server's own ATTEMPT_TTL.
const ASKING = 'asking'
const ASKING_SECONDS = 600
const ANSWER_TIMEOUT_MS = 10_000

// Module state and not a React effect: StrictMode mounts effects twice in
// development, and an attempt torn down after it set its marker would never run.
let started = false

export function startSilentSignIn(path: string | null): void {
  if (started || !path) return
  // A page that is itself framed does not ask.
  if (window.top !== window.self) return

  started = true

  // After load, so the frame never competes with first render. Only in a tab
  // someone is looking at, so a restored window of twenty tabs asks once: the
  // first to be shown sets the marker and the rest find it.
  afterLoad(() => whenShown(() => ask(path)))
}

function afterLoad(run: () => void) {
  if (document.readyState === 'complete') {
    run()
  } else {
    window.addEventListener('load', run, { once: true })
  }
}

function whenShown(run: () => void) {
  if (document.visibilityState === 'visible') {
    run()
    return
  }

  const onChange = () => {
    if (document.visibilityState !== 'visible') return
    document.removeEventListener('visibilitychange', onChange)
    run()
  }
  document.addEventListener('visibilitychange', onChange)
}

function ask(path: string) {
  // Read now and not at page load: another tab may have asked since.
  if (marker() !== null) return

  const secure = window.location.protocol === 'https:' ? '; Secure' : ''
  document.cookie = `${SILENT_TRIED_COOKIE}=${ASKING}; max-age=${ASKING_SECONDS}; path=/; SameSite=Lax${secure}`
  // A browser that keeps no cookies would ask again on every page.
  if (marker() !== ASKING) return

  const frame = document.createElement('iframe')
  frame.hidden = true
  frame.setAttribute('aria-hidden', 'true')
  frame.tabIndex = -1
  frame.title = 'Sign in with Every'
  frame.src = path

  const finish = (signedIn: boolean) => {
    window.clearTimeout(timer)
    frame.removeEventListener('load', onLoad)
    frame.remove()
    if (signedIn) reloadAsMember()
  }
  const onLoad = () => finish(signedInAccordingTo(frame))
  const timer = window.setTimeout(() => finish(false), ANSWER_TIMEOUT_MS)

  frame.addEventListener('load', onLoad)
  document.body.append(frame)
}

function marker(): string | null {
  const prefix = `${SILENT_TRIED_COOKIE}=`
  const pair = document.cookie.split('; ').find((entry) => entry.startsWith(prefix))
  return pair ? pair.slice(prefix.length) : null
}

function signedInAccordingTo(frame: HTMLIFrameElement): boolean {
  try {
    return frame.contentDocument?.body?.dataset.silentSignIn === 'signed_in'
  } catch {
    // The frame ended on a page that is not Toolbox's (Every blocked it), and
    // the browser will not let this one read it. That is a no.
    return false
  }
}

// Fetch the page's props again, now as the member: the page counts what they
// may see, the header shows them and the agent tools register, with scroll and
// component state kept. On the sign-in page the reload is forwarded to where
// the person was heading, and a member who has not finished onboarding is
// forwarded to /welcome, as after a clicked sign-in.
function reloadAsMember() {
  try {
    router.reload({
      // Inertia opens its error dialog for an answer that is not an Inertia
      // page. Toolbox's own 404 page is one, sent with status 404, and must
      // still be taken, so only the others are turned away.
      onHttpException: (response) => (response.headers['x-inertia'] ? undefined : false),
      onNetworkError: () => false,
    })
  } catch {
    // The visitor did not ask for this. A reload that fails leaves the page as it was.
  }
}

// Test seam: the once-per-page guard is module state.
export function resetSilentSignInForTests(): void {
  started = false
}
