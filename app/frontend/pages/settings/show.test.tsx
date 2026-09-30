import { act, fireEvent, render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import type { ReactNode } from 'react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { VISIBILITY_CONSEQUENCE } from '../../lib/visibility_copy'
import SettingsShow from './show'

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
    props: { flash: {}, public_host: 'toolbox.example.test', current_user: { name: 'Cy Every', avatar_url: null, handle: 'cy' } },
    url: '/settings',
  }),
}))

const account = { name: 'Cy Every', handle: 'cy', bio: 'Video tools.', visibility: 'only_me' as const }
const agents = [
  { id: 'client-1', name: 'Cursor', connected_at: '2020-01-01T00:00:00Z', last_used_at: null },
  { id: 'client-2', name: 'Claude Code', connected_at: '2020-01-01T00:00:00Z', last_used_at: '2020-06-01T00:00:00Z' },
]

const save = () => screen.getByRole('button', { name: 'Save changes' })
const linkField = () => screen.getByRole('textbox', { name: /your link/i })

describe('Settings', () => {
  beforeEach(() => {
    router.get.mockReset()
    router.patch.mockReset()
    router.delete.mockReset()
  })
  afterEach(() => {
    vi.useRealTimers()
    vi.restoreAllMocks()
  })

  it('shows a read-only name, the link under the configured host, the bio and the current level', () => {
    render(<SettingsShow account={account} agents={[]} />)

    expect(screen.getByRole('heading', { level: 1, name: 'Settings' })).toBeInTheDocument()
    const name = screen.getByRole('textbox', { name: 'Name' })
    expect(name).toHaveValue('Cy Every')
    expect(name).toHaveAttribute('readonly')
    expect(screen.getByText('Shown on your page. Change it in your Every account.')).toBeInTheDocument()
    expect(linkField()).toHaveValue('cy')
    expect(screen.getByText('toolbox.example.test/', { selector: 'span' })).toBeInTheDocument()
    expect(screen.getByText('Changing it breaks old links to your page.')).toBeInTheDocument()
    expect(screen.getByRole('textbox', { name: 'One line about how you work' })).toHaveValue('Video tools.')
    expect(screen.getByRole('radio', { name: /private/i })).toBeChecked()
    expect(screen.getByText('Your picks still count anonymously toward Every’s totals.')).toBeInTheDocument()
    expect(screen.getByText(VISIBILITY_CONSEQUENCE.only_me)).toBeInTheDocument()
    expect(document.body.textContent).not.toContain('toolbox.every.to')
  })

  it('keeps Save off until something changes, then sends handle, bio and level in one PATCH', async () => {
    render(<SettingsShow account={account} agents={[]} />)
    expect(save()).toBeDisabled()
    expect(screen.getByText('No changes yet')).toBeInTheDocument()

    await userEvent.click(screen.getByRole('radio', { name: /every team/i }))
    expect(screen.getByText('Unsaved changes')).toBeInTheDocument()
    expect(save()).toBeEnabled()
    await userEvent.click(save())

    expect(router.patch).toHaveBeenCalledWith(
      '/settings',
      { handle: 'cy', bio: 'Video tools.', visibility: 'team' },
      expect.objectContaining({ preserveScroll: true, preserveState: true }),
    )
  })

  it('says what each level means under the selected card', async () => {
    render(<SettingsShow account={account} agents={[]} />)

    await userEvent.click(screen.getByRole('radio', { name: /anyone with the link/i }))
    expect(screen.getByText(VISIBILITY_CONSEQUENCE.link)).toBeInTheDocument()
    expect(screen.queryByText(VISIBILITY_CONSEQUENCE.only_me)).not.toBeInTheDocument()

    await userEvent.click(screen.getByRole('radio', { name: /every team/i }))
    expect(screen.getByText(VISIBILITY_CONSEQUENCE.team)).toBeInTheDocument()
    expect(screen.getByText('People on the Every team.')).toBeInTheDocument()
  })

  it('confirms a save with Saved until the next edit', async () => {
    const { rerender } = render(<SettingsShow account={account} agents={[]} />)

    await userEvent.type(screen.getByRole('textbox', { name: 'One line about how you work' }), '!')
    await userEvent.click(save())
    // The redirect brings the saved account back as new props.
    act(() => router.patch.mock.calls[0][2].onSuccess())
    rerender(<SettingsShow account={{ ...account, bio: 'Video tools.!' }} agents={[]} />)

    expect(screen.getByRole('status')).toHaveTextContent('Saved')
    expect(save()).toBeDisabled()

    await userEvent.type(screen.getByRole('textbox', { name: 'One line about how you work' }), '?')
    expect(screen.getByRole('status')).toHaveTextContent('Unsaved changes')
  })

  it('counts the bio against 160 characters', async () => {
    render(<SettingsShow account={account} agents={[]} />)

    expect(screen.getByText('12/160')).toBeInTheDocument()
    await userEvent.type(screen.getByRole('textbox', { name: 'One line about how you work' }), 'xx')
    expect(screen.getByText('14/160')).toBeInTheDocument()
  })

  it('checks a changed handle live and only lets a free one be saved', () => {
    vi.useFakeTimers()
    const { rerender } = render(<SettingsShow account={account} agents={[]} />)

    expect(screen.getByText('toolbox.example.test/cy is yours.')).toBeInTheDocument()
    fireEvent.change(linkField(), { target: { value: 'Cyrus' } })
    expect(screen.getByText('Checking…')).toBeInTheDocument()
    expect(save()).toBeDisabled()
    act(() => vi.advanceTimersByTime(300))
    expect(router.get).toHaveBeenCalledWith(
      '/handles/check',
      { handle: 'cyrus' },
      expect.objectContaining({ only: ['availability'], preserveUrl: true }),
    )

    rerender(<SettingsShow account={account} agents={[]} availability={{ handle: 'cyrus', available: false, message: 'toolbox.example.test/cyrus is taken.' }} />)
    expect(screen.getByText('toolbox.example.test/cyrus is taken.')).toBeInTheDocument()
    expect(save()).toBeDisabled()

    rerender(<SettingsShow account={account} agents={[]} availability={{ handle: 'cyrus', available: true, message: 'toolbox.example.test/cyrus is yours.' }} />)
    expect(save()).toBeEnabled()
    fireEvent.click(save())
    expect(router.patch).toHaveBeenCalledWith('/settings', expect.objectContaining({ handle: 'cyrus' }), expect.any(Object))
  })

  it('shows a refusal from the server next to the field it belongs to', async () => {
    render(<SettingsShow account={account} agents={[]} />)

    await userEvent.type(screen.getByRole('textbox', { name: 'One line about how you work' }), '!')
    await userEvent.click(save())
    act(() => router.patch.mock.calls[0][2].onError({ bio: 'Bio is too long (maximum is 160 characters)' }))

    expect(screen.getByRole('alert')).toHaveTextContent('Bio is too long')
  })

  it('lists connected agents with a revoke that asks first and targets the client id', async () => {
    const confirm = vi.spyOn(window, 'confirm').mockReturnValueOnce(false).mockReturnValueOnce(true)
    render(<SettingsShow account={account} agents={agents} />)

    expect(screen.getByText('Cursor')).toBeInTheDocument()
    expect(screen.getByText('Claude Code')).toBeInTheDocument()
    expect(screen.getByText(/last used/)).toBeInTheDocument()

    await userEvent.click(screen.getByRole('button', { name: 'Revoke Cursor' }))
    expect(confirm).toHaveBeenCalledWith(expect.stringContaining('Disconnect Cursor?'))
    expect(router.delete).not.toHaveBeenCalled()

    await userEvent.click(screen.getByRole('button', { name: 'Revoke Cursor' }))
    expect(router.delete).toHaveBeenCalledWith('/agents/client-1')
  })

  it('says so when no agent is connected and links to set one up', () => {
    render(<SettingsShow account={account} agents={[]} />)

    expect(screen.getByText('No agent is connected.')).toBeInTheDocument()
    expect(screen.queryByRole('button', { name: /revoke/i })).not.toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Set up an agent' })).toHaveAttribute('href', '/agents')
  })

  it('downloads the history through a plain link, not an Inertia visit', () => {
    render(<SettingsShow account={account} agents={[]} />)

    const link = screen.getByRole('link', { name: 'Download my history' })
    expect(link).toHaveAttribute('href', '/settings/history')
    expect(link).toHaveAttribute('download')
  })

  it('keeps Delete off until the exact handle is typed, then deletes with it', async () => {
    render(<SettingsShow account={account} agents={[]} />)

    const zone = screen.getByRole('form', { name: 'Delete my account' })
    const button = within(zone).getByRole('button', { name: 'Delete my account' })
    const input = within(zone).getByLabelText('Type cy to confirm')
    expect(button).toBeDisabled()

    await userEvent.type(input, 'nope')
    expect(button).toBeDisabled()

    await userEvent.clear(input)
    await userEvent.type(input, 'cy')
    expect(button).toBeEnabled()
    await userEvent.click(button)

    expect(router.delete).toHaveBeenCalledWith('/settings', expect.objectContaining({ data: { confirmation: 'cy' } }))
  })

  it('shows the server refusing a deletion', async () => {
    render(<SettingsShow account={account} agents={[]} />)

    await userEvent.type(screen.getByLabelText('Type cy to confirm'), 'cy')
    await userEvent.click(screen.getByRole('button', { name: 'Delete my account' }))
    act(() => router.delete.mock.calls[0][1].onError({ confirmation: 'Type cy to confirm.' }))

    expect(screen.getByRole('alert')).toHaveTextContent('Type cy to confirm.')
  })
})
