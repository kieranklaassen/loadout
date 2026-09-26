# Module: frontend

Inertia.js + Vite + React 19 + TypeScript + Tailwind v4, rooted at `app/frontend`,
with SSR wired but off by default.

## What this module is

- `app/frontend` layout with snake_case page identifiers mirroring
  `controller#action` (`render inertia: "home/index"` → `app/frontend/pages/home/index.tsx`).
- A base **`InertiaController`** that every page controller inherits from, carrying
  all `inertia_share` (flash, locale, feedback-capture gate) — so a new page
  cannot ship without shared context.
- Initializer defaults: `version` as a re-evaluated lambda (`ViteRuby.digest`),
  `encrypt_history`, `always_include_errors_hash`,
  `use_script_element_for_initial_page`, `use_data_inertia_head_attribute`.
- A single entrypoint that branches `hydrateRoot`/`createRoot` on
  `data-server-rendered`, so **SSR turns on with no entrypoint change**. SSR is
  disabled by default; `config/initializers/inertia_ssr_timeout.rb` bounds the SSR
  HTTP call. See `INERTIA_SSR_ENABLED` / `npm run build:ssr`.
- Split `tsconfig.app.json` / `tsconfig.node.json` and `npm run check`
  (tsc ×2 + Vitest). TypeScript pinned to `^5.7` (the stable end of the fleet's
  drift), not the generator's 7.x.

## Files (the module boundary)

- `app/frontend/**` (entrypoints, pages, lib, styles, ssr, types, test setup)
- `app/controllers/inertia_controller.rb`, `app/controllers/application_controller.rb`
- `config/initializers/inertia_rails.rb`, `config/initializers/inertia_ssr_timeout.rb`
- `vite.config.ts`, `config/vite.json`, `tsconfig*.json`, `package.json`
- `app/views/layouts/application.html.erb`, `Procfile.dev`, `bin/dev`, `bin/vite`

## Adopt into an existing app

1. Run the `inertia:install` generator (`--framework react --typescript --vite
   --tailwind`), then apply the house conventions above.
2. Pin TypeScript to `^5.7`; add the split tsconfig + `npm run check`.
3. Add the SSR keys + `inertia_ssr_timeout.rb`, and the `data-server-rendered`
   branch in the entrypoint (SSR stays off).

## Verify adoption

- `bin/dev` boots web + Vite; `GET /` renders an Inertia page (200 + component).
- `npm run check` is green; `bin/rails test test/controllers/home_controller_test.rb`
  and `test/initializers/inertia_ssr_timeout_test.rb` pass.
