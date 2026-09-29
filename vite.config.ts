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
  // ...and pick React's production build up front: Node in the container has no NODE_ENV.
  define: isSsrBuild ? { 'process.env.NODE_ENV': '"production"' } : {},
}))
