import { describe, expect, it } from 'vitest'

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

  it('finds no violation in any shipped source', () => {
    const offenders = Object.entries(sources).flatMap(([file, source]) =>
      findSizeViolations(source).map((v) => `${file}:${v.line} ${v.text}`),
    )
    expect(offenders).toEqual([])
  })
})

// The retired paper-and-ink palette: utilities and variables of the old theme, and its component classes.
const OLD_NAMES = [
  /(?<![\w-])(?:[\w-]+:)*(?:(?:bg|text|border|ring|fill|stroke|from|to|via|divide|outline|decoration|shadow|accent|caret|placeholder)-(?:paper|ink|rule)(?:-deep|-soft|-muted)?|rounded-card|shadow-(?:card|lift)|animate-(?:rise|slot|burst))(?![\w-])/g,
  /every-(?:blue|sky|lime|coral)/g,
  /--(?:color-(?:paper|ink|rule)|radius-card|shadow-(?:card|lift)|animate-(?:rise|slot|burst))/g,
  /^\s*\.(?:display|card|eyebrow|hairline)(?![\w-])/gm,
]

const OLD_CLASSES = ['display', 'card', 'eyebrow', 'hairline']
const UTILITY =
  /^(?:[\w-]+:)*!?(?:-?(?:text|bg|border|p[xytblr]?|m[xytblr]?|w|h|size|gap|space|rounded|font|leading|tracking|shadow|opacity|z|inset|top|left|right|bottom|items|justify|min|max|col|row|overflow)-\S+|flex|grid|block|inline|inline-flex|hidden|relative|absolute|fixed|sticky|uppercase|underline|truncate|sr-only)$/

export function findOldPalette(source: string): { line: number; text: string }[] {
  const found: { index: number; text: string }[] = []

  for (const pattern of OLD_NAMES) {
    for (const match of source.matchAll(pattern)) found.push({ index: match.index, text: match[0].trim() })
  }

  // "card" and "display" are ordinary words, so only a string that is a class list counts:
  // one that follows className=, or holds a Tailwind utility beside the word.
  for (const match of source.matchAll(/(["'`])((?:\\.|(?!\1)[^\\\n])*)\1/g)) {
    const tokens = match[2].split(/\s+/).filter(Boolean)
    const word = tokens.find((token) => OLD_CLASSES.includes(token))
    const classList = /className=\{?\s*$/.test(source.slice(0, match.index)) || tokens.some((token) => UTILITY.test(token))
    if (word && classList) found.push({ index: match.index, text: word })
  }

  return found
    .map(({ index, text }) => ({ line: source.slice(0, index).split('\n').length, text }))
    .sort((a, b) => a.line - b.line)
}

describe('design rules: the old palette is gone', () => {
  it('flags the retired utilities, with any variant prefix', () => {
    const source =
      '<div className="bg-paper text-ink border-rule hover:bg-paper-deep md:text-ink-soft rounded-card shadow-lift animate-rise text-every-blue" />'
    expect(findOldPalette(source).map((v) => v.text)).toEqual([
      'bg-paper',
      'text-ink',
      'border-rule',
      'hover:bg-paper-deep',
      'md:text-ink-soft',
      'rounded-card',
      'shadow-lift',
      'animate-rise',
      'every-blue',
    ])
    expect(findOldPalette('<i className="ring-every-sky bg-every-lime text-every-coral text-ink-muted" />')).toHaveLength(4)
  })

  it('flags the retired theme variables and component selectors in CSS', () => {
    expect(findOldPalette(':root { --color-paper: #fdfaf7; --color-ink: #121212; }')).toHaveLength(2)
    expect(findOldPalette('@theme { --radius-card: 1rem; --shadow-lift: none; --animate-burst: b 1s; }')).toHaveLength(3)
    expect(findOldPalette('.card {\n  background: white;\n}\n.hairline {\n  border-color: red;\n}')).toHaveLength(2)
    expect(findOldPalette('  .eyebrow { color: red; }')).toHaveLength(1)
  })

  it('flags the retired component classes inside a class list', () => {
    expect(findOldPalette('<h1 className="display mt-3 text-[40px]">x</h1>')).toEqual([{ line: 1, text: 'display' }])
    expect(findOldPalette("const heading = 'eyebrow text-fg-muted'")).toHaveLength(1)
    expect(findOldPalette('<p className={`hairline ${extra}`}>x</p>')).toHaveLength(1)
    expect(findOldPalette('<p className="card">x</p>')).toHaveLength(1)
    expect(findOldPalette('<a>\n<p className="p-4 card">x</p>\n</a>')).toEqual([{ line: 2, text: 'card' }])
  })

  it('passes the Every dark tokens, radio-card, and plain words that only look alike', () => {
    const source = [
      '<div className="panel bg-panel text-fg-muted border-line rounded-soft ring-sky" />',
      '<label className="radio-card">x</label>',
      "const title = 'Share card for a link-only profile'",
      "const label = 'card'",
      "el.style.display = 'none'",
      "const note = 'a card for sign-in'",
      '<div className="text-inkwell text-rules" />',
      '.dot-grid { background-size: 28px 28px; }',
      '.radio-card:has(input:checked) { box-shadow: none; }',
    ].join('\n')
    expect(findOldPalette(source)).toEqual([])
  })

  it('finds no old-palette name in shipped sources', () => {
    const offenders = Object.entries(sources).flatMap(([file, source]) =>
      findOldPalette(source).map((v) => `${file}:${v.line} ${v.text}`),
    )
    expect(offenders).toEqual([])
  })
})
