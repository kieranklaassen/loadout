// Keep the union in step with config/flipper_flag_defaults.yml. Empty while no flag is live.
export type FlipperFlagName = never
type Flags = Partial<Record<FlipperFlagName, boolean>>

let cache: Flags | null = null

function read(): Flags {
  if (cache) return cache
  const el = typeof document === 'undefined' ? null : document.getElementById('flipper-flags')
  try {
    cache = el?.textContent ? (JSON.parse(el.textContent) as Flags) : {}
  } catch {
    cache = {}
  }
  return cache
}

export const resetFlipperFlagsCache = (): void => {
  cache = null
}
export const useFlipperFlag = (name: FlipperFlagName): boolean => read()[name] === true
