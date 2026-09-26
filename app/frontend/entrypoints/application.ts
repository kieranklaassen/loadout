// Page-wide bootstrap, loaded by every layout render alongside the Inertia
// entrypoint (see app/views/layouts/application.html.erb). Keep this for
// concerns that are not tied to a page component.

import { registerServiceWorker } from '~/lib/pwa'

// PWA: register the Inertia-safe service worker once the page has loaded so it
// never competes with first render. See docs/modules/pwa.md.
if (document.readyState === 'complete') {
  void registerServiceWorker()
} else {
  window.addEventListener('load', () => void registerServiceWorker(), { once: true })
}
