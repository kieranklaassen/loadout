import { render, screen } from '@testing-library/react'
import { describe, expect, it, vi } from 'vitest'
import Home from './index'

vi.mock('@inertiajs/react', () => ({
  Head: () => null,
}))

describe('Home page', () => {
  it('asks the question and offers Sign in with Every', () => {
    render(<Home />)

    expect(screen.getByRole('heading', { name: /what's in your ai loadout/i })).toBeInTheDocument()
    expect(screen.getByRole('link', { name: /sign in with every/i })).toHaveAttribute('href', '/auth/every')
  })
})
