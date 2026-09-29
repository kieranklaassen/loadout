import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import Chip, { contextLabel, effortLabel } from './chip'
import Count from './count'
import SectionLabel from './section_label'

describe('Chip', () => {
  it('writes a pick context and effort the way the design does', () => {
    expect(contextLabel('1m')).toBe('1M context')
    expect(contextLabel('200k')).toBe('200K context')
    expect(effortLabel('high')).toBe('high effort')
    expect(effortLabel('low')).toBe('low effort')
  })

  it('is neutral by default and yellow only for the newest tone', () => {
    render(
      <>
        <Chip>1M context</Chip>
        <Chip tone="newest">Newest</Chip>
      </>,
    )

    expect(screen.getByText('1M context')).not.toHaveClass('bg-yellow')
    expect(screen.getByText('1M context')).toHaveClass('bg-raised', 'rounded-sharp')
    expect(screen.getByText('Newest')).toHaveClass('bg-yellow', 'uppercase', 'text-on-light')
  })
})

describe('Count', () => {
  it('writes N of M, with an optional label', () => {
    render(
      <>
        <Count count={{ n: 5, of: 6 }} label="use it" />
        <Count count={{ n: 3, of: 11 }} />
      </>,
    )

    expect(screen.getByText('5 of 6 use it')).toBeInTheDocument()
    expect(screen.getByText('3 of 11')).toBeInTheDocument()
  })
})

describe('SectionLabel', () => {
  it('is an uppercase mono span by default and a label for a field when asked', () => {
    render(
      <>
        <SectionLabel>Tool</SectionLabel>
        <SectionLabel as="label" htmlFor="tool-1">
          Model
        </SectionLabel>
        <input id="tool-1" />
      </>,
    )

    expect(screen.getByText('Tool')).toHaveClass('font-mono', 'uppercase', 'text-xs')
    expect(screen.getByLabelText('Model')).toBe(document.getElementById('tool-1'))
  })
})
