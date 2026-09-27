import { resetFlipperFlagsCache } from '../lib/flipper_flags'

export function clearFlipperFlags(): void {
  document.getElementById('flipper-flags')?.remove()
  resetFlipperFlagsCache()
}

export function setFlipperFlags(flags: Record<string, boolean>): void {
  clearFlipperFlags()
  const el = Object.assign(document.createElement('script'), { type: 'application/json', id: 'flipper-flags' })
  el.textContent = JSON.stringify(flags)
  document.body.appendChild(el)
}
