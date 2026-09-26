// SSR entrypoint — built by `npm run build:ssr` into public/vite-ssr/ssr.js,
// which config/initializers/inertia_rails.rb points `ssr_bundle` at.
//
// SSR is OFF by default (INERTIA_SSR_ENABLED unset). This file exists so that
// enabling SSR is a build-and-flag step with no code change: it mirrors the CSR
// entrypoint's page resolution and renders each page to a string on the server.
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
        '../pages/**/*.tsx',
        { eager: true },
      )
      return pages[`../pages/${name}.tsx`]
    },
    setup: ({ App, props }) => <App {...props} />,
  }),
)
