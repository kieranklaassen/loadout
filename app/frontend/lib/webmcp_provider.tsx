import type { GlobalEvent } from '@inertiajs/core'
import { router } from '@inertiajs/react'
import { type ReactNode, useEffect, useState } from 'react'
import { getModelContext, registerTools, type WebmcpManifest } from './webmcp'

/**
 * Registers the manifest's tools on the browser's model context while
 * `manifest` is non-null, and unregisters them when it becomes null, changes,
 * or the component unmounts. A browser without WebMCP does nothing.
 *
 * The effect keys on the serialized manifest, so a partial reload that re-sends
 * an equal manifest does not re-register (duplicate names reject), and
 * StrictMode's mount→cleanup→mount aborts the first registration before the
 * second runs. After a tool that is not read-only succeeds the page reloads its
 * props, so what an agent wrote (a suggestion, say) shows without a refresh.
 */
export function useWebmcpTools(manifest: WebmcpManifest | null): void {
  const key = manifest ? JSON.stringify(manifest) : null

  useEffect(() => {
    if (!key) return
    const context = getModelContext()
    if (!context) return

    const controller = new AbortController()
    registerTools(context, JSON.parse(key) as WebmcpManifest, controller.signal, () => router.reload())
    return () => controller.abort()
  }, [key])
}

interface WebmcpProviderProps {
  /** The first page's `webmcp` shared prop: null when signed out. */
  initialManifest: WebmcpManifest | null
  children: ReactNode
}

/**
 * Sits above Inertia's `<App>` and follows every visit's `webmcp` prop, so
 * signing in registers the tools and signing out unregisters them without a
 * full page load and without a persistent layout. A reload of the same page
 * is followed too.
 */
export default function WebmcpProvider({ initialManifest, children }: WebmcpProviderProps) {
  const [manifest, setManifest] = useState(initialManifest)

  useEffect(() => {
    const follow = (event: GlobalEvent<'navigate' | 'success'>) => {
      const props = event.detail.page.props as { webmcp?: WebmcpManifest | null }
      setManifest(props.webmcp ?? null)
    }

    // `navigate` is not fired when a visit lands on the address the page
    // already has, which is what the reload after an automatic sign-in does
    // (lib/silent_sign_in.ts). `success` is.
    const stopNavigate = router.on('navigate', follow)
    const stopSuccess = router.on('success', follow)
    return () => {
      stopNavigate()
      stopSuccess()
    }
  }, [])

  useWebmcpTools(manifest)

  return <>{children}</>
}
