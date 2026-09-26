# Module: riffrec

Riffrec feedback capture, wired in as a default module that **no-ops safely when
unconfigured** and carries **no real credential or live endpoint** anywhere in
the repo. It points at a riffrec-dashboard connection purely through placeholder
env vars.

## What this module is

- `config/initializers/riffrec.rb` defines `Riffrec.configured?` (true only when
  BOTH `RIFFREC_PUBLIC_KEY` and `RIFFREC_ENDPOINT` are set) and `Riffrec.client_config`
  (the endpoint + the browser-publishable capture key — never a server secret).
- `InertiaController` shares `feedback_capture_enabled` (the boolean gate) and
  `riffrec` (the client config, `nil` when unconfigured) with every page.
- `RiffrecProvider` (client) wraps the whole app, always renders its children
  unchanged, and mounts the capture widget only when enabled. It reads its config
  from the initial page's shared props (passed in the Vite entrypoint's `setup`),
  so it can sit above `<App>` without needing the Inertia page context.

## The drop-in point (stub → real widget)

The template ships a **stub** provider so it boots with no private package and no
secrets. The single line to change when adopting the live widget is in
`app/frontend/lib/riffrec_provider.tsx`, inside the `useEffect`:

```ts
import { mount } from 'riffrec'   // github:kieranklaassen/riffrec
const unmount = mount({ endpoint: config.endpoint, publicKey: config.public_key })
return unmount
```

## Invariant: no secrets, no live endpoints

`.env.example` carries `RIFFREC_PUBLIC_KEY=` and `RIFFREC_ENDPOINT=` as **names
only**. No real key or live hostname appears anywhere in the repo. `client_config`
exposes only the endpoint and a publishable key — never a server secret. Enforced
by `test/controllers/riffrec_share_test.rb`.

## Files (the module boundary)

- `config/initializers/riffrec.rb`
- `app/controllers/inertia_controller.rb` (the two shared props)
- `app/frontend/lib/riffrec_provider.tsx`, `app/frontend/lib/riffrec_provider.test.tsx`
- `app/frontend/entrypoints/inertia.tsx` (wraps `<App>` in `RiffrecProvider`)
- `.env.example` (`RIFFREC_PUBLIC_KEY` / `RIFFREC_ENDPOINT` placeholder names)
- `test/controllers/riffrec_share_test.rb`

## Adopt into an existing app

1. Copy `config/initializers/riffrec.rb` and add the two `inertia_share` lines to
   the base Inertia controller.
2. Copy `RiffrecProvider` and wrap `<App>` with it in the Vite entrypoint's `setup`.
3. Add the `RIFFREC_*` names to `.env.example`.
4. To go live: set `RIFFREC_PUBLIC_KEY` + `RIFFREC_ENDPOINT` in the environment and
   apply the drop-in edit above.

## Verify adoption

- `bin/rails test test/controllers/riffrec_share_test.rb`
- `npm run test` (the `RiffrecProvider` component test)
- With `RIFFREC_*` unset, `GET /` shares `feedback_capture_enabled: false` and no config.
