// SSR entrypoint — built by `vite build --ssr` (run by `bin/rails assets:precompile`,
// see ssrBuildEnabled in config/vite.json) into public/vite-ssr/ssr.js, which
// config/initializers/inertia_rails.rb points `ssr_bundle` at and bin/ssr runs.
//
// It mirrors the CSR entrypoint's page resolution and renders each page to a
// string on the server. Test files stay out of the glob: they import vitest, which
// cannot boot outside a test run.
import { createInertiaApp } from '@inertiajs/react'
import createServer from '@inertiajs/react/server'
import type { ComponentType } from 'react'
import { renderToString } from 'react-dom/server'

void createServer((page) =>
  createInertiaApp({
    page,
    render: renderToString,
    // Mirror the CSR entrypoint's snake_case "controller/action" resolution.
    resolve: (name) => {
      const pages = import.meta.glob<{ default: ComponentType }>(
        ['../pages/**/*.tsx', '!../pages/**/*.test.tsx'],
        { eager: true },
      )
      return pages[`../pages/${name}.tsx`]
    },
    setup: ({ App, props }) => <App {...props} />,
  }),
)
