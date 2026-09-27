import { describe, expect, it } from 'vitest'
import source from '../entrypoints/application.css?raw'

const css = source.replace(/\/\*[\s\S]*?\*\//g, '')

/** The declarations of the first rule whose selector list contains `selector`. */
function rule(selector: string) {
  const match = [...css.matchAll(/([^{}]+)\{([^{}]*)\}/g)].find(([, selectors]) => selectors.split(',').some((s) => s.trim() === selector))
  if (!match) throw new Error(`No rule for ${selector}`)
  return match[2]
}

const SKY_OUTLINE = /outline:\s*2px solid var\(--color-sky\)/

describe('Every dark tokens', () => {
  it.each([
    ['page', '#020202'],
    ['panel', '#111111'],
    ['line', '#2a2a2a'],
    ['fg', '#fdfaf7'],
    ['fg-soft', '#d0d0d0'],
    ['fg-muted', '#8c8d91'],
    ['sky', '#9ce5f5'],
    ['yellow', '#f6b90f'],
    ['coral', '#ff7765'],
  ])('defines --color-%s as %s', (name, value) => {
    expect(css).toMatch(new RegExp(`--color-${name}:\\s*${value};`))
  })

  it('paints the layout body page-black with the dot grid and cream text', () => {
    expect(rule('body')).toMatch(/background-color:\s*var\(--color-page\)/)
    expect(rule('body')).toMatch(/color:\s*var\(--color-fg\)/)
    expect(rule('.dot-grid')).toMatch(/radial-gradient\(circle at center, rgb\(255 255 255 \/ 0\.07\) 0 1\.5px, transparent 2px\)/)
    expect(rule('.dot-grid')).toMatch(/background-size:\s*28px 28px/)
  })

  it('keeps corners at 2px and 4px and the smallest caption at 13px', () => {
    expect(css).toMatch(/--radius-sharp:\s*2px;/)
    expect(css).toMatch(/--radius-soft:\s*4px;/)
    expect(css).toMatch(/--text-caption:\s*0\.8125rem;/)
  })

  it('self-hosts the fonts through fontsource and never loads from Google', () => {
    expect(css).toContain("@import '@fontsource-variable/hanken-grotesk';")
    expect(css).toContain("@import '@fontsource-variable/newsreader/opsz.css';")
    expect(css).toContain("@import '@fontsource/geist-mono/400.css';")
    expect(css).not.toMatch(/googleapis|gstatic/)
  })
})

describe('form controls', () => {
  it('declares a dark colour scheme on the root', () => {
    expect(rule(':root')).toMatch(/color-scheme:\s*dark/)
  })

  it('sets explicit colours on select options', () => {
    const declarations = rule('option')
    expect(declarations).toMatch(/background-color:\s*var\(--color-field\)/)
    expect(declarations).toMatch(/color:\s*var\(--color-fg\)/)
  })

  it('gives inputs, selects and textareas the shared 3px-offset sky focus ring', () => {
    for (const selector of ['input:focus-visible', 'select:focus-visible', 'textarea:focus-visible', ':focus-visible']) {
      expect(rule(selector), selector).toMatch(SKY_OUTLINE)
      expect(rule(selector), selector).toMatch(/outline-offset:\s*3px/)
    }
  })

  it('rings the wrapper of a select or input, and the card of a hidden radio', () => {
    expect(rule('.field-box:has(:focus-visible)')).toMatch(SKY_OUTLINE)
    expect(rule('.field-box :focus-visible')).toMatch(/outline:\s*none/)
    expect(rule('.radio-card:has(input:focus-visible)')).toMatch(SKY_OUTLINE)
    expect(rule('.radio-card:has(input:checked)')).toMatch(/box-shadow:\s*0 0 0 2px var\(--color-sky\)/)
    expect(rule('.radio-card input')).toMatch(/opacity:\s*0/)
  })
})

describe('responsive rules', () => {
  it('uses the single 768px breakpoint (48rem) for the stacked-card helpers', () => {
    expect(css).toMatch(/@media \(width < 48rem\)\s*\{[\s\S]*\.stack-table[\s\S]*\.stack-row/)
    expect(css).not.toMatch(/@media \(width < (?!48rem)/)
  })

  it('shows each cell label above its value when stacked', () => {
    expect(css).toMatch(/\.stack-table \[data-label\]::before,\s*\.stack-row \[data-label\]::before\s*\{[^}]*content:\s*attr\(data-label\)/)
  })

  it('lays the four slot fields out 2 x 2 on phones and in one row from 768px', () => {
    expect(rule('.slot-fields')).toMatch(/repeat\(2, minmax\(0, 1fr\)\)/)
    expect(css).toMatch(/@media \(width >= 48rem\)\s*\{\s*\.slot-fields\s*\{[^}]*1\.3fr 1\.3fr 1fr 1fr/)
  })
})
