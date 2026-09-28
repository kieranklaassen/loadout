import { render, screen, within } from '@testing-library/react'
import type { ComponentProps, ReactNode } from 'react'
import { describe, expect, it, vi } from 'vitest'
import Consent from './consent'
import OauthError from './error'

vi.mock('@inertiajs/react', () => ({
  Head: () => null,
  Link: ({ href, children, ...rest }: { href: string; children: ReactNode }) => (
    <a href={href} {...rest}>
      {children}
    </a>
  ),
  router: { delete: vi.fn() },
  usePage: () => ({
    props: { flash: {}, public_host: 'toolbox.example.test', current_user: { name: 'Cy Every', avatar_url: null, handle: 'cy' } },
    url: '/oauth/authorize',
  }),
}))

type Props = ComponentProps<typeof Consent>

const CAPABILITIES = {
  can: ['Read your toolbox', 'Suggest picks, which stay hidden until you confirm'],
  cannot: ['Confirm or dismiss suggestions', 'Change who can see your page'],
  webmcp_note: 'A browser agent that uses WebMCP works inside your signed-in session, so it can also click buttons on the page.',
}

const props = (overrides: Partial<Props> = {}): Props => ({
  client: { name: 'Claude Code', redirect_host: '127.0.0.1', mark: null, known: false },
  redirect_host: '127.0.0.1',
  authorization: {
    client_id: 'client-1',
    redirect_uri: 'http://127.0.0.1:5555/callback',
    response_type: 'code',
    code_challenge: 'c'.repeat(43),
    code_challenge_method: 'S256',
    state: 'state-1',
  },
  authenticity_token: 'csrf-token-1',
  capabilities: CAPABILITIES,
  ...overrides,
})

const form = () => document.querySelector('form') as HTMLFormElement
const fields = () => Object.fromEntries(new FormData(form()).entries())

describe('Consent page', () => {
  it('names the client who is asking and who is signed in', () => {
    render(<Consent {...props()} />)

    expect(screen.getByRole('heading', { level: 1, name: 'Claude Code wants to fill in your toolbox' })).toBeInTheDocument()
    expect(screen.getByText('Cy Every')).toBeInTheDocument()
  })

  it('lists what it can and can’t do exactly as the server sends it, with the WebMCP note', () => {
    render(<Consent {...props()} />)

    for (const line of [...CAPABILITIES.can, ...CAPABILITIES.cannot]) expect(screen.getByText(line)).toBeInTheDocument()
    expect(screen.getByText(CAPABILITIES.webmcp_note)).toBeInTheDocument()
  })

  describe('who the client is', () => {
    it('gives an unlisted client a serif initial, never a mark', () => {
      render(<Consent {...props()} />)

      const tile = screen.getByTitle('Claude Code')
      expect(tile).toHaveTextContent('C')
      expect(tile.querySelector('svg')).toBeNull()
    })

    it('shows the real mark for a known client', () => {
      render(<Consent {...props({ client: { name: 'Claude', redirect_host: 'claude.ai', mark: 'claude', known: true }, redirect_host: 'claude.ai' })} />)

      const tile = screen.getByTitle('Claude')
      expect(tile.querySelector('svg')).not.toBeNull()
      expect(tile).not.toHaveTextContent('C')
    })

    it('ignores a mark on a client that is not known', () => {
      render(<Consent {...props({ client: { name: 'Claude', redirect_host: 'example.org', mark: 'claude', known: false }, redirect_host: 'example.org' })} />)

      expect(screen.getByTitle('Claude').querySelector('svg')).toBeNull()
    })

    it('always shows where the member goes after approving', () => {
      render(<Consent {...props({ redirect_host: 'cursor://anysphere.cursor-retrieval' })} />)

      expect(screen.getByText('cursor://anysphere.cursor-retrieval')).toBeInTheDocument()
      expect(screen.queryByText(/on your computer/i)).not.toBeInTheDocument()
    })

    it('says plainly when the app runs on this computer', () => {
      render(<Consent {...props()} />)

      expect(screen.getByText('127.0.0.1')).toBeInTheDocument()
      expect(screen.getByText(/an app running on your computer/i)).toBeInTheDocument()
    })
  })

  describe('the decision form', () => {
    it('posts to /oauth/authorize as a native form with the CSRF token and every authorization parameter', () => {
      render(<Consent {...props()} />)

      expect(form()).toHaveAttribute('method', 'post')
      expect(form()).toHaveAttribute('action', '/oauth/authorize')
      expect(fields()).toEqual({
        authenticity_token: 'csrf-token-1',
        client_id: 'client-1',
        redirect_uri: 'http://127.0.0.1:5555/callback',
        response_type: 'code',
        code_challenge: 'c'.repeat(43),
        code_challenge_method: 'S256',
        state: 'state-1',
      })
    })

    it('sends the decision in the pressed button’s value', () => {
      render(<Consent {...props()} />)

      const allow = within(form()).getByRole('button', { name: 'Allow' })
      const deny = within(form()).getByRole('button', { name: 'Deny' })
      expect([allow, deny].map((button) => [button.getAttribute('name'), button.getAttribute('value'), button.getAttribute('type')])).toEqual([
        ['decision', 'approve', 'submit'],
        ['decision', 'deny', 'submit'],
      ])
    })

    it('makes Deny a visible button, not a label', () => {
      render(<Consent {...props()} />)

      expect(screen.getByRole('button', { name: 'Deny' })).toHaveClass('border', 'border-fg-muted')
    })
  })

  it('links the way to turn it off again', () => {
    render(<Consent {...props()} />)

    expect(screen.getByRole('link', { name: 'Agents page' })).toHaveAttribute('href', '/agents')
  })
})

describe('OAuth error page', () => {
  it('shows the message and no way back to the client', () => {
    render(<OauthError message="This app asked to send you somewhere it never registered, so Toolbox stopped here." />)

    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('That connection didn’t check out')
    expect(screen.getByText(/never registered, so Toolbox stopped here/)).toBeInTheDocument()
    const hrefs = screen.getAllByRole('link').map((link) => link.getAttribute('href'))
    expect(hrefs.length).toBeGreaterThan(0)
    for (const href of hrefs) expect(href).toMatch(/^\//)
    expect(screen.getByRole('link', { name: 'How to connect an agent' })).toHaveAttribute('href', '/agents')
  })
})
