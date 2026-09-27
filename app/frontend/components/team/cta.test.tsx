import { render, screen } from '@testing-library/react'
import type { ReactNode } from 'react'
import { describe, expect, it, vi } from 'vitest'
import Cta, { EmptyState } from './cta'

vi.mock('@inertiajs/react', () => ({
  Link: ({ href, children, ...rest }: { href: string; children: ReactNode }) => (
    <a href={href} {...rest}>
      {children}
    </a>
  ),
}))

const join = { label: 'Join Every', href: 'https://every.to' }
const start = { label: 'Rank your first tools', href: '/loadout/edit' }

describe('Cta', () => {
  it('asks a visitor to join Every, with Sign in beside it', () => {
    render(<Cta cta={join} signedIn={false} />)

    expect(screen.getByRole('link', { name: 'Join Every' })).toHaveAttribute('href', 'https://every.to')
    expect(screen.getByRole('link', { name: 'Already a subscriber? Sign in' })).toHaveAttribute('href', '/session/new')
  })

  it('asks a member with nothing ranked to start, without a Sign in link', () => {
    render(<Cta cta={start} signedIn />)

    expect(screen.getByRole('link', { name: 'Rank your first tools' })).toHaveAttribute('href', '/loadout/edit')
    expect(screen.queryByRole('link', { name: /Sign in/ })).not.toBeInTheDocument()
  })
})

describe('EmptyState', () => {
  it('says nobody has shared and offers Join Every to a visitor, with no zero-of-zero', () => {
    render(<EmptyState cta={join} signedIn={false} />)

    expect(screen.getByRole('heading', { name: 'Nobody has shared a loadout yet' })).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Join Every' })).toBeInTheDocument()
    expect(screen.queryByText(/of 0/)).not.toBeInTheDocument()
  })

  it('offers a member to be the first', () => {
    render(<EmptyState cta={start} signedIn />)

    expect(screen.getByRole('link', { name: 'Rank your first tools' })).toBeInTheDocument()
  })

  it('offers nothing to a member who already has picks', () => {
    render(<EmptyState cta={null} signedIn />)

    expect(screen.getByRole('heading', { name: 'Nobody has shared a loadout yet' })).toBeInTheDocument()
    expect(screen.queryByRole('link')).not.toBeInTheDocument()
  })
})
