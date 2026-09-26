import { act, fireEvent, render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { catalog, coding, video } from '../../test/picker_fixtures'
import OnboardingShow from './show'

const router = vi.hoisted(() => ({ get: vi.fn(), patch: vi.fn() }))

vi.mock('@inertiajs/react', () => ({
  Head: () => null,
  router,
  usePage: () => ({ props: { flash: {}, current_user: null } }),
}))

const baseProps = {
  handle: null,
  suggested_handle: 'olive',
  first_name: 'Olive',
  every_member: true,
  public: false,
  picker: { categories: [coding, video], catalog, picks: {} },
}

describe('Onboarding', () => {
  beforeEach(() => {
    router.get.mockReset()
    router.patch.mockReset()
    window.scrollTo = vi.fn()
  })
  afterEach(() => vi.useRealTimers())

  it('prefills the suggested handle and claims it', async () => {
    render(<OnboardingShow {...baseProps} step="handle" />)

    expect(screen.getByRole('textbox', { name: /your link/i })).toHaveValue('olive')
    expect(screen.getByText('loadout.every.to/olive is yours.')).toBeInTheDocument()

    await userEvent.click(screen.getByRole('button', { name: /claim it/i }))
    expect(router.patch).toHaveBeenCalledWith('/welcome/handle', { handle: 'olive' }, expect.objectContaining({ preserveState: 'errors' }))
  })

  it('checks a typed handle live through a partial reload of /handles/check', () => {
    vi.useFakeTimers()
    render(<OnboardingShow {...baseProps} step="handle" />)

    fireEvent.change(screen.getByRole('textbox', { name: /your link/i }), { target: { value: 'Olive J' } })
    expect(screen.getByText('Checking…')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: /claim it/i })).toBeDisabled()
    act(() => vi.advanceTimersByTime(300))

    expect(router.get).toHaveBeenCalledWith(
      '/handles/check',
      { handle: 'olive-j' },
      expect.objectContaining({ only: ['availability'], preserveUrl: true }),
    )
  })

  it('shows the availability answer for the current value', () => {
    render(
      <OnboardingShow
        {...baseProps}
        step="handle"
        suggested_handle="map-person"
        availability={{ handle: 'map-person', available: false, message: 'loadout.every.to/map-person is taken.' }}
      />,
    )
    fireEvent.change(screen.getByRole('textbox', { name: /your link/i }), { target: { value: 'map-person' } })

    expect(screen.getByText('loadout.every.to/map-person is yours.')).toBeInTheDocument()
  })

  it('skips picks straight to visibility, private by default, and finishes', async () => {
    render(<OnboardingShow {...baseProps} handle="olive" step="picks" />)

    await userEvent.click(screen.getByRole('button', { name: /skip for now/i }))
    expect(router.patch).not.toHaveBeenCalled()
    expect(screen.getByRole('radio', { name: /just me/i })).toHaveAttribute('aria-checked', 'true')
    expect(screen.getByText(/count, anonymously, in the Every map/i)).toBeInTheDocument()

    await userEvent.click(screen.getByRole('radio', { name: /anyone with the link/i }))
    await userEvent.click(screen.getByRole('button', { name: /finish and see my loadout/i }))
    expect(router.patch).toHaveBeenCalledWith('/welcome/finish', { public: true, next: null }, expect.any(Object))
  })

  it('saves touched categories through PATCH /loadout', async () => {
    render(<OnboardingShow {...baseProps} handle="olive" step="picks" />)

    await userEvent.click(screen.getByRole('button', { name: 'Cursor' }))
    expect(screen.getByText('1 pick · 1 category')).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: /continue/i }))

    expect(router.patch).toHaveBeenCalledWith(
      '/loadout',
      { operations: [{ op: 'replace_category', category: 'coding', picks: [{ tool: 'cursor', model: null, primary: true, note: null }] }] },
      expect.objectContaining({ preserveState: true }),
    )
  })

  it('offers the agent path as an equal alternative', async () => {
    render(<OnboardingShow {...baseProps} handle="olive" step="picks" />)

    await userEvent.click(screen.getByRole('button', { name: /rather let your agent do it/i }))
    await userEvent.click(screen.getByRole('button', { name: /finish and connect your agent/i }))

    expect(router.patch).toHaveBeenCalledWith('/welcome/finish', { public: false, next: 'agents' }, expect.any(Object))
  })
})
