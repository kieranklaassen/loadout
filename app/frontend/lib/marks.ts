// Every real mark is an inline SVG file in app/frontend/assets/marks/, named by its
// catalog key (claudecode.svg for `mark: 'claudecode'`). Keys resolve against this
// list of files, never by building a path from a key.
const files = import.meta.glob<string>('../assets/marks/*.svg', { query: '?raw', import: 'default', eager: true })

const MARKS = new Map(Object.entries(files).map(([path, svg]) => [path.slice(path.lastIndexOf('/') + 1, -'.svg'.length), svg]))

/** The SVG markup for a catalog `mark` key, or null when the item has no real mark. */
export function markSvg(key: string | null | undefined) {
  return (key && MARKS.get(key)) || null
}
