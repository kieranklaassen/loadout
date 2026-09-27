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

## Design system in this app: Every dark

Loadout is dark and Every-branded. The tokens live in `app/frontend/entrypoints/application.css`
(`@theme`), and the design of record is `docs/design/every-loadout/` (`DESIGN-BRIEF.md` and the
page mocks, which are layout truth only: their names, counts and dates are placeholders). Tailwind
scans only `app/frontend`, so utility classes never go in ERB.

- **Colour tokens**, each a Tailwind utility (`bg-*`, `text-*`, `border-*`, `ring-*`): `page`
  `#020202`, `panel` `#111111`, `field`, `raised`, the `line`, `line-strong` and `line-quiet`
  borders, the text ladder `fg`, `fg-soft` and `fg-muted` (never dimmer), and `on-light` for text on
  a light mark. Three accents, each for one job: `sky` is only the primary call to action, the
  active filter and the italic brand word; `yellow` only NEWEST and rank 1; `coral` only stale and
  danger. Corners are `rounded-sharp` (2px) or `rounded-soft` (4px). There is no other palette.
- **Type**: Newsreader for headings, Hanken Grotesk for the UI and Geist Mono for captions, all
  self-hosted through `@fontsource` packages. Text is at least 13px (`text-caption`); only an
  uppercase mono label may be 12px (`text-xs`).
- **Marks** (`components/mark.tsx`, `lib/marks.ts`): a tool is a square light tile and a model a
  round one. `<Mark item={{ name, kind, mark }} size="md" />` draws the real single-colour SVG when
  the catalog item has a `mark` key, and the first letter of its name in the serif face otherwise.
  The SVGs are in `app/frontend/assets/marks/` and are named by catalog key; `markSvg` resolves a
  key against that list of files, never a path built from it, and its test allows only `path` and
  `g` elements. The share card reads the same folder. Keys are set in `config/catalog.yml`.
- **Building blocks**: `Count` writes every "N of M" the same way (`<Count count={{ n: 5, of: 6 }}
  label="use it" />`), and a page shows an empty state instead of "0 of 0". Also `Chip`,
  `SectionLabel`, `Button` and `ButtonLink`, `Avatar`, `Wordmark` and `AppShell`. The CSS
  classes `dot-grid`, `panel`, `text-link`, `field-box` and `radio-card` cover the page, cards, links,
  form controls and radio cards. Page-specific pieces live in `components/{team,kind,profile,rank}/`.
- **Responsive helpers**: there is one breakpoint, 768px (`md:`). Below it `stack-table` and
  `stack-row` turn a table or a grid row into stacked cards (a cell's `data-label` shows above its
  value), `slot-fields` becomes a 2 x 2 grid, and interactive targets stay at least 44px tall
  (`min-h-11 md:min-h-0`). Motion is CSS only and still under `prefers-reduced-motion`; the Home
  hero also has a pause control.
- **Hosts**: pages print the display host from the `public_host` shared prop (`usePublicHost()`),
  never a literal.
- **Design-rules test** (`app/frontend/test/design_rules.test.ts`): scans every shipped source
  file and fails on text below the minimums and on any class or token from the removed v1 light
  palette. Its list of exempt legacy files is empty; keep it that way.

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
