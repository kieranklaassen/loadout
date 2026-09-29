import { describe, expect, it } from 'vitest'
import { rankLabel } from './rank_label'

describe('rankLabel', () => {
  it('writes ranks the way the page says them', () => {
    expect([1, 2, 3].map(rankLabel)).toEqual(['1st', '2nd', '3rd'])
  })
})
