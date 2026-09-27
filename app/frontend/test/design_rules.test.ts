import { describe, expect, it } from 'vitest'

/**
 * v1 files that still break the size rules below. Each surface unit deletes the files
 * it converts from this list (the "still violates" test below makes it) and U13
 * asserts the list is empty. Paths are relative to app/frontend.
 */
export const LEGACY_FILES: string[] = [
  'components/catalog_search.tsx',
  'components/category_card.tsx',
  'components/map_rank.tsx',
  'components/tool_mark.tsx',
  'pages/agents/index.tsx',
  'pages/home/index.tsx',
  'pages/map/show.tsx',
  'pages/oauth/consent.tsx',
  'pages/profiles/show.tsx',
]

// The design brief's text minimums: 12px for uppercase mono labels, 13px for everything else.
const MIN_LABEL_PX = 12
const MIN_TEXT_PX = 13

type Violation = { line: number; px: number; text: string }

const px = (value: string, unit?: string) => Number(value) * (unit === 'rem' || unit === 'em' ? 16 : 1)

// Sizes written in source: Tailwind arbitrary values, CSS declarations, inline style objects.
const SIZE_PATTERNS = [
  /\btext-\[(?:length:)?(\d*\.?\d+)(px|rem|em)\]/g,
  /\bfont-size:\s*(\d*\.?\d+)(px|rem|em)/g,
  /\bfontSize:\s*['"]?(\d*\.?\d+)(px|rem|em)?['"]?/g,
]

// Tailwind's only named size under 13px is text-xs (12px).
const TEXT_XS = /(?:^|[\s'"`:!])text-xs(?![\w-])/g

/** The text a size sits in: its line, or for CSS the whole rule, checked for "uppercase mono label". */
function isUppercaseMonoLabel(context: string) {
  return /\buppercase\b/.test(context) && /mono/.test(context)
}

export function findSizeViolations(source: string): Violation[] {
  const violations: Violation[] = []

  const check = (index: number, size: number, text: string) => {
    if (size >= MIN_TEXT_PX) return
    const before = source.slice(0, index)
    const lineEnd = source.indexOf('\n', index)
    const lineText = source.slice(before.lastIndexOf('\n') + 1, lineEnd === -1 ? undefined : lineEnd)
    const ruleText = source.slice(source.lastIndexOf('{', index), source.indexOf('}', index))
    const label = isUppercaseMonoLabel(lineText) || (text.startsWith('font-size') && isUppercaseMonoLabel(ruleText))
    if (size < MIN_LABEL_PX || !label) violations.push({ line: before.split('\n').length, px: size, text })
  }

  for (const pattern of SIZE_PATTERNS) {
    for (const match of source.matchAll(pattern)) check(match.index, px(match[1], match[2]), match[0])
  }
  for (const match of source.matchAll(TEXT_XS)) check(match.index, 12, 'text-xs')

  return violations.sort((a, b) => a.line - b.line)
}

// Every shipped source file (not tests), keyed by its path relative to app/frontend.
const sources = Object.fromEntries(
  Object.entries(
    import.meta.glob<string>(['../**/*.{ts,tsx,css}', '!../**/*.test.{ts,tsx}'], { query: '?raw', import: 'default', eager: true }),
  ).map(([path, source]) => [path.replace(/^\.\.\//, ''), source]),
)

describe('design rules: minimum text sizes', () => {
  it('flags an arbitrary size under 12px anywhere', () => {
    expect(findSizeViolations('<p className="text-[11px] text-fg">x</p>')).toEqual([{ line: 1, px: 11, text: 'text-[11px]' }])
    expect(findSizeViolations('<p className="md:text-[0.7rem] uppercase font-mono">x</p>')).toHaveLength(1)
    expect(findSizeViolations('const style = { fontSize: 11 }')).toHaveLength(1)
    expect(findSizeViolations('.note { font-size: 0.72rem; }')).toHaveLength(1)
  })

  it('flags 12px text unless it is an uppercase mono label', () => {
    expect(findSizeViolations('<p className="text-xs text-fg-muted">x</p>')).toHaveLength(1)
    expect(findSizeViolations('<p className="font-mono text-xs">x</p>')).toHaveLength(1)
    expect(findSizeViolations('<p className="text-[12px] font-mono">x</p>')).toHaveLength(1)
    expect(findSizeViolations('<p className="font-mono text-xs uppercase">x</p>')).toEqual([])
    expect(findSizeViolations('.label { font-family: var(--font-mono); text-transform: uppercase; font-size: 0.75rem; }')).toEqual([])
    expect(findSizeViolations('.label {\n  font-family: var(--font-mono);\n  text-transform: uppercase;\n  font-size: 0.75rem;\n}')).toEqual([])
  })

  it('passes 13px and up, the caption token, and non-size text utilities', () => {
    const source = '<p className="text-[13px] text-caption text-sm text-[#fff] text-[var(--x)] text-xs-wide">x</p>'
    expect(findSizeViolations(source)).toEqual([])
  })

  it('reports the line of each violation', () => {
    const lines = findSizeViolations('<a>\n<p className="text-[10px]">x</p>\n<p className="text-[9px]">y</p>\n</a>').map((v) => v.line)
    expect(lines).toEqual([2, 3])
  })

  it('finds no violation in shipped sources outside the legacy list', () => {
    const offenders = Object.entries(sources)
      .filter(([file]) => !LEGACY_FILES.includes(file))
      .flatMap(([file, source]) => findSizeViolations(source).map((v) => `${file}:${v.line} ${v.text}`))
    expect(offenders).toEqual([])
  })

  it('lists only legacy files that still exist and still violate', () => {
    const stale = LEGACY_FILES.filter((file) => !sources[file] || findSizeViolations(sources[file]).length === 0)
    expect(stale).toEqual([])
  })
})
