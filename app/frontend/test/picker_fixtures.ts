import type { CatalogItem, PickerCatalog, PickerCategory } from '../types'

const item = (slug: string, name: string, maker: string, hue = 220): CatalogItem => ({
  slug,
  name,
  maker,
  hue,
  monogram: name.slice(0, 2),
  pending: false,
})

export const cursor = item('cursor', 'Cursor', 'Anysphere')
export const claudeCode = item('claude-code', 'Claude Code', 'Anthropic', 18)
export const claude = item('claude', 'Claude', 'Anthropic', 18)
export const runway = item('runway', 'Runway', 'Runway', 345)
export const opus = item('claude-opus-5-5', 'Claude Opus 5.5', 'Anthropic', 18)
export const gpt = item('gpt-6-astra', 'GPT-6 Astra', 'OpenAI', 160)

export const catalog: PickerCatalog = {
  tools: [cursor, claudeCode, claude, runway],
  models: [opus, gpt],
}

export const coding: PickerCategory = {
  slug: 'coding',
  name: 'Coding',
  blurb: 'Writing, reviewing, and shipping code.',
  tool_slugs: ['cursor', 'claude-code'],
  model_slugs: ['claude-opus-5-5', 'gpt-6-astra'],
}

export const video: PickerCategory = {
  slug: 'video',
  name: 'Video',
  blurb: 'Generating and editing video.',
  tool_slugs: ['runway'],
  model_slugs: [],
}
