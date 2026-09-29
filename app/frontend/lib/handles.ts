/** Mirrors User::Handle normalization, so the live check compares like with like. */
export function normalizeHandle(value: string) {
  return value.trim().toLowerCase().replace(/^@/, '')
}
