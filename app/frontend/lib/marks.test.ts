import { describe, expect, it } from 'vitest'
import { markSvg } from './marks'

const files = import.meta.glob<string>('../assets/marks/*.svg', { query: '?raw', import: 'default', eager: true })

// Marks are inlined as markup, so a file may hold only vector shapes: no script, style, link or image.
const ALLOWED_ELEMENTS = ['svg', 'path', 'g']

describe('mark files', () => {
  it('ships the ten tool and model marks', () => {
    const keys = Object.keys(files).map((path) => path.replace(/^.*\/|\.svg$/g, ''))
    expect(keys.sort()).toEqual(
      ['claude', 'claudecode', 'cursor', 'elevenlabs', 'google', 'googlegemini', 'openai', 'perplexity', 'rive', 'suno'].sort(),
    )
  })

  it.each(Object.entries(files))('%s contains only svg, path and g elements', (path, source) => {
    const doc = new DOMParser().parseFromString(source, 'image/svg+xml')
    expect(doc.querySelector('parsererror')).toBeNull()

    const names = [...doc.querySelectorAll('*')].map((element) => element.localName)
    expect(names.filter((name) => !ALLOWED_ELEMENTS.includes(name)), path).toEqual([])
    expect(doc.documentElement.localName).toBe('svg')
  })
})

describe('markSvg', () => {
  it('returns the markup for a shipped key', () => {
    expect(markSvg('claudecode')).toBe(files['../assets/marks/claudecode.svg'])
  })

  it('returns null for no key, an unknown key, and anything that is not a bare file key', () => {
    expect(markSvg(null)).toBeNull()
    expect(markSvg(undefined)).toBeNull()
    expect(markSvg('')).toBeNull()
    expect(markSvg('nope')).toBeNull()
    expect(markSvg('../every-logo')).toBeNull()
    expect(markSvg('claude.svg')).toBeNull()
    expect(markSvg('constructor')).toBeNull()
    expect(markSvg('__proto__')).toBeNull()
  })
})
