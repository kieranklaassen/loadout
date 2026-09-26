import react from '@vitejs/plugin-react'
import { defineConfig } from 'vitest/config'

// Vitest owns its own config (not the Vite app config) so the Ruby/Tailwind/
// Inertia plugins that assume a running dev server stay out of the test run.
// Only the React transform is needed to render components under jsdom.
export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./app/frontend/test/setup.ts'],
    include: ['app/frontend/**/*.{test,spec}.{ts,tsx}'],
  },
})
