import type { Errors } from '@inertiajs/core'

/** One message per field from a visit's `onError`, which may carry several messages for a field. */
export function fieldErrors(errors: Errors): Record<string, string> {
  return Object.fromEntries(Object.entries(errors).map(([field, messages]) => [field, [messages].flat().join(' ')]))
}
