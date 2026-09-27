import { render } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import { claudeCodeMark, markItem, opusMark } from '../test/picker_fixtures'
import Mark from './mark'

const tile = (container: HTMLElement) => container.firstElementChild as HTMLElement

describe('Mark', () => {
  it('draws a tool as a square tile and a model as a round one', () => {
    const { container: tool } = render(<Mark item={claudeCodeMark} />)
    const { container: model } = render(<Mark item={opusMark} />)

    expect(tile(tool)).toHaveAttribute('data-kind', 'tool')
    expect(tile(tool)).toHaveClass('rounded-soft')
    expect(tile(tool)).not.toHaveClass('rounded-full')
    expect(tile(model)).toHaveAttribute('data-kind', 'model')
    expect(tile(model)).toHaveClass('rounded-full')
  })

  it('shows the real mark when the item has one that resolves', () => {
    const { container } = render(<Mark item={claudeCodeMark} />)

    expect(container.querySelector('svg path')).not.toBeNull()
    expect(tile(container).textContent).toBe('')
    expect(tile(container)).toHaveClass('bg-fg')
  })

  it('shows the first letter in the serif face when there is no mark', () => {
    const { container } = render(<Mark item={markItem('acme', 'acme editor')} />)

    expect(container.querySelector('svg')).toBeNull()
    expect(tile(container)).toHaveTextContent(/^A$/)
    expect(container.querySelector('.font-serif')).toHaveTextContent('A')
  })

  it('falls back to the initial when the mark key matches no file', () => {
    const { container } = render(<Mark item={markItem('acme', 'Acme', 'model', 'not-a-mark')} />)

    expect(container.querySelector('svg')).toBeNull()
    expect(tile(container)).toHaveTextContent(/^A$/)
  })

  it('never renders two letters, however the name is written', () => {
    for (const name of ['Claude Opus 5.5', '  gpt-6 sol', 'Élan', 'GPT']) {
      const { container, unmount } = render(<Mark item={markItem('x', name)} />)
      expect(tile(container).textContent).toHaveLength(1)
      unmount()
    }
  })

  it('is decorative: it hides from assistive technology and carries the name as a tooltip', () => {
    const { container } = render(<Mark item={opusMark} size="lg" className="mr-2" />)

    expect(tile(container)).toHaveAttribute('aria-hidden', 'true')
    expect(tile(container)).toHaveAttribute('title', 'Claude Opus 5.5')
    expect(tile(container)).toHaveClass('size-11', 'mr-2')
  })
})
