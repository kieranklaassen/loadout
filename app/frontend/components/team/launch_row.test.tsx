import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import { launch } from '../../test/home_fixtures'
import LaunchRow from './launch_row'

const renderRow = (props = {}) => render(<ul><LaunchRow launch={launch(props)} /></ul>)

describe('LaunchRow', () => {
  it('opens the Vibe Check in a new tab with a safe rel and a name that says which model', () => {
    renderRow()

    const link = screen.getByRole('link', { name: 'Vibe Check for Claude Opus 5.5' })
    expect(link).toHaveAttribute('href', 'https://checks.every.to/vibe-checks/claude-opus-5-5')
    expect(link).toHaveAttribute('target', '_blank')
    expect(link).toHaveAttribute('rel', 'noopener noreferrer')
    expect(link).toHaveTextContent(/^Vibe Check/)
  })

  it('shows the model, its release date, N of M and where it is mostly used', () => {
    renderRow()

    expect(screen.getByText('Claude Opus 5.5')).toBeInTheDocument()
    expect(screen.getByText('Sep 22')).toHaveAttribute('datetime', '2026-09-22')
    expect(screen.getByRole('listitem')).toHaveTextContent('4 of 6 use it, mostly in Claude Code')
  })

  it('marks the newest launch in yellow and no other', () => {
    const { unmount } = renderRow({ newest: true })
    expect(screen.getByText('Newest')).toHaveClass('bg-yellow')
    unmount()

    renderRow({ newest: false })
    expect(screen.queryByText('Newest')).not.toBeInTheDocument()
  })

  it('leaves out "mostly in" when no tool leads', () => {
    renderRow({ mostly_in: null })

    expect(screen.getByText('4 of 6 use it')).toBeInTheDocument()
    expect(screen.queryByText(/mostly in/)).not.toBeInTheDocument()
  })

  it('never writes zero of zero when nobody has shared', () => {
    renderRow({ adoption: { n: 0, of: 0 }, mostly_in: null })

    expect(screen.queryByText(/of 0/)).not.toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Vibe Check for Claude Opus 5.5' })).toBeInTheDocument()
  })
})
