import { render, screen } from '@testing-library/react'
import type { ReactNode } from 'react'
import { describe, expect, it, vi } from 'vitest'
import Button, { ButtonLink } from './button'

vi.mock('@inertiajs/react', () => ({
  Link: ({ href, children, ...rest }: { href: string; children: ReactNode }) => (
    <a href={href} {...rest}>
      {children}
    </a>
  ),
}))

describe('Button', () => {
  it('draws the primary button in sky and the secondary one without it', () => {
    render(
      <>
        <Button>Save</Button>
        <Button variant="secondary">Cancel</Button>
      </>,
    )

    expect(screen.getByRole('button', { name: 'Save' })).toHaveClass('bg-sky', 'text-on-light')
    expect(screen.getByRole('button', { name: 'Cancel' })).not.toHaveClass('bg-sky')
    expect(screen.getByRole('button', { name: 'Cancel' })).toHaveClass('border', 'border-line', 'bg-panel')
  })

  it('has 2px corners on every variant and size', () => {
    render(
      <>
        <Button>Primary</Button>
        <Button variant="secondary" size="lg">
          Secondary
        </Button>
        <Button variant="ghost">Ghost</Button>
      </>,
    )

    for (const name of ['Primary', 'Secondary', 'Ghost']) {
      expect(screen.getByRole('button', { name })).toHaveClass('rounded-sharp')
    }
  })

  it('is a button that does not submit forms unless told to, and keeps 44px targets on phones', () => {
    render(
      <>
        <Button>Plain</Button>
        <Button type="submit">Send</Button>
      </>,
    )

    expect(screen.getByRole('button', { name: 'Plain' })).toHaveAttribute('type', 'button')
    expect(screen.getByRole('button', { name: 'Send' })).toHaveAttribute('type', 'submit')
    expect(screen.getByRole('button', { name: 'Plain' })).toHaveClass('min-h-11', 'md:min-h-0')
  })

  it('renders a link with the same look for ButtonLink', () => {
    render(
      <ButtonLink href="/agents" variant="secondary">
        Set up
      </ButtonLink>,
    )

    const link = screen.getByRole('link', { name: 'Set up' })
    expect(link).toHaveAttribute('href', '/agents')
    expect(link).toHaveClass('rounded-sharp', 'border-line')
    expect(link).not.toHaveClass('bg-sky')
  })
})
