import { type ReactNode, useEffect } from 'react'

export interface RiffrecConfig {
  endpoint: string
  public_key: string
}

interface RiffrecProviderProps {
  enabled: boolean
  config: RiffrecConfig | null
  children: ReactNode
}

/**
 * Wraps the app and mounts the feedback-capture widget when enabled.
 *
 * This is the NO-OP-DEGRADING stub the template ships: it always renders its
 * children unchanged, and mounts nothing when capture is disabled — so the
 * template boots with no private package and no secrets. When `enabled` is true,
 * the effect below is the single DROP-IN POINT for the real widget.
 */
export default function RiffrecProvider({ enabled, config, children }: RiffrecProviderProps) {
  useEffect(() => {
    if (!enabled || !config) return

    // DROP-IN POINT — replace this stub with the real riffrec npm package:
    //
    //   import { mount } from 'riffrec'   // github:kieranklaassen/riffrec
    //   const unmount = mount({ endpoint: config.endpoint, publicKey: config.public_key })
    //   return unmount
    //
    // The stub intentionally mounts nothing.
  }, [enabled, config])

  return <>{children}</>
}
