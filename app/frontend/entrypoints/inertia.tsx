import { createInertiaApp } from '@inertiajs/react'
import { StrictMode } from 'react'
import { createRoot, hydrateRoot } from 'react-dom/client'
import RiffrecProvider, { type RiffrecConfig } from '../lib/riffrec_provider'
import type { WebmcpManifest } from '../lib/webmcp'
import WebmcpProvider from '../lib/webmcp_provider'

void createInertiaApp({
  // Resolve page components from app/frontend/pages using the snake_case
  // "controller/action" identifier Rails passes to `render inertia:`.
  pages: '../pages',

  defaults: {
    form: {
      forceIndicesArrayFormatInFormData: false,
      withAllErrors: true,
    },
    visitOptions: () => {
      return { queryStringArrayFormat: 'brackets' }
    },
  },

  // Branch CSR vs SSR from a single entrypoint: when the server pre-rendered the
  // markup it stamps `data-server-rendered="true"` on the root element, so we
  // hydrate instead of mounting fresh. Turning SSR on later (see
  // config/initializers/inertia_rails.rb) touches no code here.
  setup({ el, App, props }) {
    if (!el) return

    // Feedback-capture config is a static server setting, read once from the
    // initial page's shared props (not usePage, so this wrapper sits above App).
    const shared = props.initialPage.props as {
      feedback_capture_enabled?: boolean
      riffrec?: RiffrecConfig | null
      webmcp?: WebmcpManifest | null
    }

    const app = (
      <StrictMode>
        <RiffrecProvider
          enabled={Boolean(shared.feedback_capture_enabled)}
          config={shared.riffrec ?? null}
        >
          <WebmcpProvider initialManifest={shared.webmcp ?? null}>
            <App {...props} />
          </WebmcpProvider>
        </RiffrecProvider>
      </StrictMode>
    )

    if (el.dataset.serverRendered === 'true') {
      hydrateRoot(el, app)
    } else {
      createRoot(el).render(app)
    }
  },
}).catch((error) => {
  // This ensures this entrypoint is only loaded on Inertia pages by checking for
  // the presence of the root element (#app by default).
  if (document.getElementById('app')) {
    throw error
  } else {
    console.error(
      'Missing root element.\n\n' +
        'If you see this error, it probably means you loaded Inertia.js on non-Inertia pages.\n' +
        'Consider moving <%= vite_typescript_tag "inertia.tsx" %> to the Inertia-specific layout instead.',
    )
  }
})
