import type { Errors } from '@inertiajs/core'
import { describe, expect, it } from 'vitest'
import { fieldErrors } from './field_errors'

describe('fieldErrors', () => {
  it('keeps one message per field, joining several', () => {
    expect(fieldErrors({ handle: ['is taken'], bio: ['is too long', 'has odd characters'] })).toEqual({
      handle: 'is taken',
      bio: 'is too long has odd characters',
    })
  })

  it('takes a plain string as well as a list, since Rails sends one message per field', () => {
    expect(fieldErrors({ handle: 'is taken' } as unknown as Errors)).toEqual({ handle: 'is taken' })
  })

  it('is empty when nothing was refused', () => {
    expect(fieldErrors({})).toEqual({})
  })
})
