# Module: pwa

Installable Progressive Web App out of the box: a web app manifest, a minimal
Inertia-safe service worker with an offline fallback, the `<head>` tags browsers
look for, and client-side registration — all driven by one config file.

## What this module is

- **Rails' built-in `Rails::PwaController`** serves `/manifest.json` and
  `/service-worker` from `app/views/pwa/*`. It sits outside `InertiaController`,
  so both are public (no session) and unaffected by `allow_browser`.
- **One identity source:** `config/initializers/pwa.rb` (`config.x.pwa` — name,
  short name, description, theme and background colours). The manifest, the
  layout's `<title>` fallback, `application-name`, and `theme-color` metas all
  read it. Re-branding an app is a one-file edit.
- **A deliberately minimal service worker.** It precaches only
  `public/offline.html` and `public/icon.png` (the icon is served cache-first so
  the offline page renders it while the network is down), intercepts only
  full-page navigations (`request.mode === "navigate"`), and falls back to the
  offline page **only when `fetch` rejects** (network error, server down). Every
  HTTP response — including 4xx/5xx — is returned unmodified, and Inertia XHR
  visits and Vite assets are never touched. No dynamic caching: Inertia's
  page-version checks and XHR round trip do not survive a caching layer. Its
  caches are namespaced `pwa-*`; activation prunes only stale keys under that
  prefix and leaves any other CacheStorage user on the origin alone.
- **Registration** from `app/frontend/lib/pwa.ts`, called by the
  `application.ts` entrypoint after `load`. SSR-safe, no-op without browser
  support, never throws, once per page lifecycle.

## Files (the module boundary)

- `config/initializers/pwa.rb` — the identity config
- `app/views/pwa/manifest.json.erb`, `app/views/pwa/service-worker.js`
- `public/offline.html`, `public/icon.png`, `public/icon.svg`
- `config/routes.rb` — the two `rails/pwa#…` routes (formats pinned: manifest
  `format: true, constraints: { format: "json" }`; service-worker
  `defaults: { format: :js }, constraints: { format: "js" }`)
- `app/views/layouts/application.html.erb` — manifest link, `theme-color`,
  `application-name`, `<title>` fallback reading `config.x.pwa`
- `app/frontend/lib/pwa.ts`, `app/frontend/lib/pwa.test.ts`,
  `app/frontend/entrypoints/application.ts`
- `test/controllers/pwa_test.rb`

Depends on the **frontend** module (layout + Vite entrypoint).

## Adopt into an existing app

1. Copy `config/initializers/pwa.rb` and set the app's name, short name,
   description, and colours.
2. Copy `app/views/pwa/manifest.json.erb` and `app/views/pwa/service-worker.js`
   (overwrite the Rails-generated comment-only versions) and `public/offline.html`.
   Supply a 512×512 `public/icon.png` (see the icon note below).
3. In `config/routes.rb`, add (or uncomment and amend) the two routes:
   `get "manifest" => "rails/pwa#manifest", as: :pwa_manifest, format: true, constraints: { format: "json" }` and
   `get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker, defaults: { format: :js }, constraints: { format: "js" }`.
4. In the layout, read `Rails.application.config.x.pwa` for the `<title>`
   fallback and `application-name`, add `<meta name="theme-color">`, and emit
   `tag.link rel: "manifest", href: pwa_manifest_path(format: :json)`.
5. Copy `app/frontend/lib/pwa.ts` + `pwa.test.ts` and call
   `registerServiceWorker()` from your page-wide entrypoint after `load`.
6. Copy `test/controllers/pwa_test.rb`; run the verification below.
7. Add `pwa: "<template_version>"` to `.template-manifest.yml`.

## Verify adoption

- `bin/rails test test/controllers/pwa_test.rb test/controllers/home_controller_test.rb`
  passes; `npm run check` is green.
- `curl -s localhost:<port>/manifest.json | jq .name` prints the configured name;
  `curl -sI localhost:<port>/service-worker` shows `text/javascript`.
- In Chromium DevTools → Application: the manifest parses with no errors and a
  service worker is *activated* with scope `/`. Tick **Offline** and reload → the
  offline page; untick → live pages, and Inertia visits still work.

## Gotchas

- **The worker is sticky.** Once registered it persists across deploys. It calls
  `skipWaiting()`/`clients.claim()` so updates take over promptly, but the cache
  is keyed by `CACHE_VERSION` — bump it whenever `offline.html`, `icon.png`, or
  the precache list changes (the icon is served cache-first from the worker).
  To reset locally: DevTools → Application → Service Workers → Unregister, then
  Clear storage.
- **Precache uses `cache: "reload"` on purpose.** `public/` ships with a 1-year
  `cache-control` in production (2 days in development). Without the bypass, a
  new `CACHE_VERSION` would be refilled from the stale browser HTTP cache.
- **Stopped dev server shows the offline page.** With the worker registered, a
  `bin/dev` restart renders `offline.html` ("can't reach the server") instead of
  the browser's connection error. That is expected; the copy covers both cases.
- **Safari and `*.localhost`.** Chromium and Firefox treat copse's
  `<branch>.<app>.localhost` hostnames as secure contexts; Safari does not, so
  `navigator.serviceWorker` is absent there and registration silently no-ops.
  Local installability checks are Chromium/Firefox.
- **Route format pin.** Rails collapses browser-like `Accept` headers (including
  the integration-test default) to `[:html]`; without `defaults: { format: :js }`
  the extension-less `/service-worker` raises `MissingTemplate`. The
  `constraints` make mismatched URLs 404 at routing rather than 500 in the view
  layer: `/manifest.json` is the only manifest URL — bare `/manifest` and
  `/service-worker.json` are 404.
- **Icons.** The manifest reuses `public/icon.png` for both `purpose: any` and
  `purpose: maskable`. A maskable icon needs safe-zone padding (keep the artwork
  within the central ~80%); the template icon is unpadded and may be cropped on
  some launchers — replace it with your own.
- **CSP.** No CSP is active in the template. If you enable one, allow
  `worker-src 'self'` and `manifest-src 'self'`. `Rails::ApplicationController`
  (the PWA controller's parent) also carries its own controller-level
  `content_security_policy` block, independent of the app initializer.
- **`allow_browser` does not apply** to `Rails::PwaController` — do not "fix"
  that by moving the routes onto `ApplicationController`; installability needs
  them public.
- **Web Push is not included.** The commented `push`/`notificationclick`
  handlers in the service worker mark where it goes; VAPID keys, subscription
  storage, and an install-prompt UI are follow-up work.
