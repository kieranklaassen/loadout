import { usePage } from '@inertiajs/react'
import type { SharedProps } from '../types'

/** What pages show until the server sends `public_host`. */
export const DEFAULT_PUBLIC_HOST = 'toolbox.every.to'

/** The display host for links and the footer, from the `public_host` shared prop. */
export function usePublicHost() {
  return usePage<SharedProps>().props.public_host || DEFAULT_PUBLIC_HOST
}
