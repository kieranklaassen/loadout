import { act, fireEvent, render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import type { ReactNode } from 'react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { VISIBILITY_CONSEQUENCE, VISIBILITY_STATUS } from '../../lib/visibility_copy'
import OnboardingShow from './show'

const router = vi.hoisted(() => ({ get: vi.fn(), patch: vi.fn(), delete: vi.fn() }))

vi.mock('@inertiajs/react', () => ({
  Head: () => null,
  Link: ({ href, children, ...rest }: { href: string; children: ReactNode }) => (
    <a href={href} {...rest}>
      {children}
    </a>
  ),
  router,
  usePage: () => ({
    props: { flash: {}, public_host: 'toolbox.example.test', current_user: { name: 'Olive Jones', avatar_url: null, handle: null } },
    url: '/welcome',
  }),
}))

const baseProps = {
  suggested_handle: 'olive-jones',
  name: 'Olive Jones',
  avatar_url: null,
  visibility: 'only_me' as const,
  preview_kinds: ['Coding', 'Knowledge work'],
}

const linkField = () => screen.getByRole('textbox', { name: /your link/i })

describe('Claim your link', () => {
  beforeEach(() => {
    router.get.mockReset()
    router.patch.mockReset()
  })
  afterEach(() => vi.useRealTimers())

  it('prefills the suggested handle under the configured host, not a hard-coded one', () => {
    render(<OnboardingShow {...baseProps} />)

    expect(screen.getByRole('heading', { level: 1, name: 'Claim your link' })).toBeInTheDocument()
    expect(linkField()).toHaveValue('olive-jones')
    expect(screen.getByText('toolbox.example.test/', { selector: 'span' })).toBeInTheDocument()
    expect(screen.getByText('toolbox.example.test/olive-jones is yours.')).toBeInTheDocument()
    expect(document.body.textContent).not.toContain('toolbox.every.to')
  })

  it('shows the preview: name, link and two empty kinds, updating with the handle', () => {
    render(<OnboardingShow {...baseProps} />)

    const preview = screen.getByText('Preview').parentElement as HTMLElement
    expect(within(preview).getByText('Olive Jones')).toBeInTheDocument()
    expect(within(preview).getByText('toolbox.example.test/olive-jones')).toBeInTheDocument()
    expect(within(preview).getByText('Coding')).toBeInTheDocument()
    expect(within(preview).getByText('Knowledge work')).toBeInTheDocument()
    expect(within(preview).getAllByText('Empty')).toHaveLength(2)

    fireEvent.change(linkField(), { target: { value: 'olive' } })
    expect(within(preview).getByText('toolbox.example.test/olive')).toBeInTheDocument()
  })

  it('offers the three levels, private by default, and says what the chosen one means', async () => {
    render(<OnboardingShow {...baseProps} />)

    const group = screen.getByRole('radiogroup', { name: 'Who can see it' })
    expect(within(group).getAllByRole('radio').map((radio) => (radio as HTMLInputElement).value)).toEqual(['only_me', 'team', 'link'])
    expect(screen.getByRole('radio', { name: /only me/i })).toBeChecked()
    expect(screen.getByRole('radio', { name: /every team/i })).not.toBeChecked()
    expect(screen.getByText('People on the Every team.')).toBeInTheDocument()
    expect(screen.getByText(VISIBILITY_CONSEQUENCE.only_me)).toBeInTheDocument()
    expect(screen.getByText(VISIBILITY_STATUS.only_me)).toBeInTheDocument()

    await userEvent.click(screen.getByRole('radio', { name: /every team/i }))

    expect(screen.getByRole('radio', { name: /every team/i })).toBeChecked()
    expect(screen.getByText(VISIBILITY_CONSEQUENCE.team)).toBeInTheDocument()
    expect(screen.queryByText(VISIBILITY_CONSEQUENCE.only_me)).not.toBeInTheDocument()
    expect(screen.getByText(VISIBILITY_STATUS.team)).toBeInTheDocument()

    await userEvent.click(screen.getByRole('radio', { name: /anyone with the link/i }))
    expect(screen.getByText(VISIBILITY_CONSEQUENCE.link)).toBeInTheDocument()
    expect(screen.getByText(VISIBILITY_STATUS.link)).toBeInTheDocument()
  })

  it('keeps the radios reachable and described for a keyboard user', async () => {
    render(<OnboardingShow {...baseProps} />)

    const radio = screen.getByRole('radio', { name: /only me/i })
    expect(radio).toHaveAccessibleDescription(VISIBILITY_CONSEQUENCE.only_me)
    linkField().focus()
    await userEvent.tab()
    expect(radio).toHaveFocus()
    await userEvent.keyboard('{ArrowDown}')
    expect(screen.getByRole('radio', { name: /every team/i })).toBeChecked()
  })

  it('saves the handle and the chosen level with one PATCH to /welcome', async () => {
    render(<OnboardingShow {...baseProps} />)

    await userEvent.click(screen.getByRole('radio', { name: /anyone with the link/i }))
    await userEvent.click(screen.getByRole('button', { name: 'Save and rank my first tools' }))

    expect(router.patch).toHaveBeenCalledWith('/welcome', { handle: 'olive-jones', visibility: 'link' }, expect.objectContaining({ preserveState: true }))
  })

  it('checks a typed handle live through a partial reload of /handles/check and waits for the answer', () => {
    vi.useFakeTimers()
    render(<OnboardingShow {...baseProps} />)

    fireEvent.change(linkField(), { target: { value: 'Olive J' } })
    expect(screen.getByText('Checking…')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Save and rank my first tools' })).toBeDisabled()
    act(() => vi.advanceTimersByTime(300))

    expect(router.get).toHaveBeenCalledWith(
      '/handles/check',
      { handle: 'olive-j' },
      expect.objectContaining({ only: ['availability'], preserveUrl: true }),
    )
  })

  it('shows the answer for the current value: taken blocks saving, free allows it', () => {
    const taken = { handle: 'map-person', available: false, message: 'toolbox.example.test/map-person is taken.' }
    const { rerender } = render(<OnboardingShow {...baseProps} availability={taken} />)
    fireEvent.change(linkField(), { target: { value: 'map-person' } })

    expect(screen.getByText('toolbox.example.test/map-person is taken.')).toBeInTheDocument()
    expect(linkField()).toHaveAttribute('aria-invalid', 'true')
    expect(screen.getByRole('button', { name: 'Save and rank my first tools' })).toBeDisabled()

    rerender(<OnboardingShow {...baseProps} availability={{ ...taken, available: true, message: 'toolbox.example.test/map-person is yours.' }} />)
    expect(screen.getByText('toolbox.example.test/map-person is yours.')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Save and rank my first tools' })).toBeEnabled()
  })

  it('ignores an answer that belongs to an earlier value', () => {
    render(<OnboardingShow {...baseProps} availability={{ handle: 'older', available: true, message: 'toolbox.example.test/older is yours.' }} />)

    fireEvent.change(linkField(), { target: { value: 'newer' } })

    expect(screen.getByText('Checking…')).toBeInTheDocument()
  })

  it('shows a refusal from the server under the field and clears it when the handle changes', async () => {
    render(<OnboardingShow {...baseProps} />)

    await userEvent.click(screen.getByRole('button', { name: 'Save and rank my first tools' }))
    const options = router.patch.mock.calls[0][2]
    act(() => options.onError({ handle: 'toolbox.example.test/olive-jones was just taken. Try another.' }))

    expect(screen.getByText('toolbox.example.test/olive-jones was just taken. Try another.')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Save and rank my first tools' })).toBeDisabled()

    fireEvent.change(linkField(), { target: { value: 'olive-j' } })
    expect(screen.queryByText(/was just taken/)).not.toBeInTheDocument()
  })

  it('shows a refused level next to the radios', async () => {
    render(<OnboardingShow {...baseProps} />)

    await userEvent.click(screen.getByRole('button', { name: 'Save and rank my first tools' }))
    act(() => router.patch.mock.calls[0][2].onError({ visibility: 'Visibility is not included in the list' }))

    expect(screen.getByRole('alert')).toHaveTextContent('not included')
  })

  it('does not save a cleared handle', async () => {
    render(<OnboardingShow {...baseProps} />)

    fireEvent.change(linkField(), { target: { value: '' } })

    expect(screen.getByText('Pick a handle.')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Save and rank my first tools' })).toBeDisabled()
  })

  it('does not pull in the old picker or the welcome celebration', () => {
    render(<OnboardingShow {...baseProps} />)

    expect(screen.queryByRole('button', { name: /skip for now/i })).not.toBeInTheDocument()
    expect(screen.queryByText(/rather let your agent/i)).not.toBeInTheDocument()
  })
})
