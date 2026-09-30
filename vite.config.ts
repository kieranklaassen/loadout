import react from '@vitejs/plugin-react'
import inertia from '@inertiajs/vite'
import tailwindcss from '@tailwindcss/vite'
import { defineConfig } from 'vite'
import RubyPlugin from 'vite-plugin-ruby'

export default defineConfig(({ isSsrBuild }) => ({
  plugins: [
    tailwindcss(),
    RubyPlugin(),
    inertia(),
    react(),
  ],
  // Bundle every dependency into the SSR build: the image ships Node but no
  // node_modules, so public/vite-ssr/ssr.js has to run on its own.
  ssr: { noExternal: true },
  // Fonts stay separate files. Vite inlines any asset under 4 KB as base64, which put the
  // small Geist Mono subsets (Cyrillic, Greek, ...) into every page's stylesheet, and the
  // stylesheet is inlined into every page's HTML. As files they load only when a character
  // needs them.
  build: { assetsInlineLimit: (file) => (/\.(woff2?|ttf|otf)$/i.test(file) ? false : undefined) },
  // ...and pick React's production build up front: Node in the container has no NODE_ENV.
  define: isSsrBuild ? { 'process.env.NODE_ENV': '"production"' } : {},
}))
