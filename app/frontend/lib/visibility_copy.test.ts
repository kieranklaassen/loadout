import { describe, expect, it } from 'vitest'

import {
  VISIBILITY_CONSEQUENCE,
  VISIBILITY_HELP,
  VISIBILITY_LABEL,
  VISIBILITY_LEVELS,
  VISIBILITY_STATUS,
} from './visibility_copy'

describe('visibility copy', () => {
  it('has a label, help, consequence and status line for every level', () => {
    for (const level of VISIBILITY_LEVELS) {
      expect(VISIBILITY_LABEL[level]).toBeTruthy()
      expect(VISIBILITY_HELP[level]).toBeTruthy()
      expect(VISIBILITY_CONSEQUENCE[level]).toBeTruthy()
      expect(VISIBILITY_STATUS[level]).toBeTruthy()
    }
  })

  it('tells people who can find and read the page', () => {
    expect(VISIBILITY_CONSEQUENCE.link).toMatch(/listed on the Every page and searchable/i)
    expect(VISIBILITY_CONSEQUENCE.team).toMatch(/connected agents/i)
    expect(VISIBILITY_CONSEQUENCE.link).toMatch(/cannot be recalled/i)
  })
})
