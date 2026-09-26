// Service worker registration for the pwa module (docs/modules/pwa.md).
//
// The worker itself lives in app/views/pwa/service-worker.js and is served by
// Rails at /service-worker. This helper only registers it — safely: it no-ops
// under SSR and in browsers without support, never throws, and registers once
// per page lifecycle.

const SERVICE_WORKER_URL = '/service-worker'

let registrationStarted = false

export async function registerServiceWorker(): Promise<void> {
  if (registrationStarted) return
  if (typeof navigator === 'undefined' || !('serviceWorker' in navigator)) return

  registrationStarted = true

  try {
    await navigator.serviceWorker.register(SERVICE_WORKER_URL, { scope: '/' })
  } catch (error) {
    // Insecure context (Safari on *.localhost), blocked storage, or a 5xx on
    // the worker script. The app works without the worker, so warn and move on.
    console.warn('[pwa] service worker registration failed:', error)
  }
}

// Test seam: the once-per-lifecycle guard is module state.
export function resetServiceWorkerRegistrationForTests(): void {
  registrationStarted = false
}
