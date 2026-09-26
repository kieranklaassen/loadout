// Minimal, Inertia-safe service worker.
//
// It exists to make the app installable and to show a friendly page when the
// server cannot be reached. It deliberately caches NOTHING dynamic: Inertia
// pages depend on the X-Inertia XHR round trip and asset-version checks, and
// caching those produces stale pages and version-mismatch reloads.
//
// Bump CACHE_VERSION whenever offline.html, the icon, or the precache list
// changes. Only caches under CACHE_PREFIX belong to this worker — activation
// prunes stale ones and leaves any other CacheStorage user on the origin alone.
const CACHE_PREFIX = "pwa-"
const CACHE_VERSION = "v1"
const CACHE_NAME = `${CACHE_PREFIX}${CACHE_VERSION}`
const OFFLINE_URL = "/offline.html"
const ICON_URL = "/icon.png"

// public/ ships with a 1-year cache-control in production, so precache requests
// bypass the browser HTTP cache — otherwise a new CACHE_VERSION would be
// refilled from the stale copy.
const PRECACHE = [OFFLINE_URL, ICON_URL].map(
  (url) => new Request(url, { cache: "reload" })
)

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches
      .open(CACHE_NAME)
      .then((cache) => cache.addAll(PRECACHE))
      .then(() => self.skipWaiting())
  )
})

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(
          keys
            .filter((key) => key.startsWith(CACHE_PREFIX) && key !== CACHE_NAME)
            .map((key) => caches.delete(key))
        )
      )
      .then(() => self.clients.claim())
  )
})

self.addEventListener("fetch", (event) => {
  // The offline page's icon is served from the precache so it renders while
  // the network is down (an <img> request is not a navigation, so it would
  // otherwise fall through to the unreachable network).
  const url = new URL(event.request.url)
  if (event.request.method === "GET" && url.origin === self.location.origin && url.pathname === ICON_URL) {
    event.respondWith(caches.match(ICON_URL).then((hit) => hit || fetch(event.request)))
    return
  }

  // Otherwise only full-page navigations are handled. Inertia XHR visits, Vite
  // assets, and any other request pass straight through untouched.
  if (event.request.mode !== "navigate") return

  event.respondWith(
    // Any HTTP response — including 4xx/5xx and redirects — is returned as-is.
    // The offline page appears only when fetch itself rejects (network error,
    // server down).
    fetch(event.request).catch(() => caches.match(OFFLINE_URL))
  )
})

// Web Push is a deferred extension of this module. When adopting it, handle
// "push" and "notificationclick" here:
//
// self.addEventListener("push", async (event) => {
//   const { title, options } = await event.data.json()
//   event.waitUntil(self.registration.showNotification(title, options))
// })
//
// self.addEventListener("notificationclick", function(event) {
//   event.notification.close()
//   event.waitUntil(
//     clients.matchAll({ type: "window" }).then((clientList) => {
//       for (let i = 0; i < clientList.length; i++) {
//         let client = clientList[i]
//         let clientPath = (new URL(client.url)).pathname
//
//         if (clientPath == event.notification.data.path && "focus" in client) {
//           return client.focus()
//         }
//       }
//
//       if (clients.openWindow) {
//         return clients.openWindow(event.notification.data.path)
//       }
//     })
//   )
// })
