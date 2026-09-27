import { act, fireEvent, render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import type { ComponentProps, ReactNode } from 'react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { installModelContext, removeModelContext } from '../../test/model_context_stub'
import AgentsIndex from './index'

const { del } = vi.hoisted(() => ({ del: vi.fn() }))

vi.mock('@inertiajs/react', () => ({
  Head: () => null,
  Link: ({ href, children, ...rest }: { href: string; children: ReactNode }) => (
    <a href={href} {...rest}>
      {children}
    </a>
  ),
  router: { delete: del },
  usePage: () => ({
    props: { flash: {}, public_host: 'loadout.example.test', current_user: { name: 'Cy Every', avatar_url: null, handle: 'cy' } },
    url: '/agents',
  }),
}))

type Props = ComponentProps<typeof AgentsIndex>
type Agent = Props['agents'][number]

const MCP_URL = 'https://mcp.example.test/mcp'
const CURSOR_URL = 'cursor://anysphere.cursor-deeplink/mcp/install?name=loadout&config=abc'
const PROMPT = 'Suggest picks for my Loadout. Ask me before you guess.'
const CAPABILITIES = {
  can: ['Read your loadout', 'Suggest picks, which stay hidden until you confirm'],
  cannot: ['Confirm or dismiss suggestions', 'Change who can see your page'],
  webmcp_note: 'A browser agent that uses WebMCP works inside your signed-in session, so it can also click buttons on the page.',
}

const agent = (overrides: Partial<Agent> = {}): Agent => ({
  id: 'client-1',
  name: 'Cursor',
  redirect_host: 'cursor://anysphere.cursor-retrieval',
  known_key: null,
  open_suggestions: 0,
  connected_at: '2020-09-12T12:00:00Z',
  last_used_at: null,
  ...overrides,
})

const props = (agents: Agent[] = []): Props => ({
  agents,
  capabilities: CAPABILITIES,
  mcp_url: MCP_URL,
  cursor_install_url: CURSOR_URL,
  suggested_prompt: PROMPT,
})

const card = (name: string) => screen.getByRole('region', { name })
const connectedList = () => screen.getByRole('region', { name: 'Connected agents' })

describe('Agents page', () => {
  const writeText = vi.fn().mockResolvedValue(undefined)

  beforeEach(() => {
    del.mockReset()
    writeText.mockClear()
    Object.defineProperty(navigator, 'clipboard', { value: { writeText }, configurable: true })
  })
  afterEach(() => {
    removeModelContext()
    vi.useRealTimers()
  })

  describe('product cards', () => {
    it('shows the four products with commands built from the mcp_url prop, never a hard-coded address', () => {
      render(<AgentsIndex {...props()} />)

      expect(screen.getByRole('heading', { level: 1, name: 'Let your agent fill it in' })).toBeInTheDocument()
      expect(card('Claude Code')).toHaveTextContent(`claude mcp add --transport http loadout ${MCP_URL}`)
      expect(card('Claude')).toHaveTextContent(MCP_URL)
      expect(card('Cursor')).toHaveTextContent(JSON.stringify({ mcpServers: { loadout: { url: MCP_URL } } }))
      expect(card('Codex')).toHaveTextContent(`codex mcp add loadout --url ${MCP_URL}`)
      expect(document.body.textContent).not.toContain('every.to/loadout')
    })

    it('offers the Cursor deep link from the prop and the manual steps for the others', () => {
      render(<AgentsIndex {...props()} />)

      expect(within(card('Cursor')).getByRole('link', { name: 'Add to Cursor' })).toHaveAttribute('href', CURSOR_URL)
      expect(card('Claude')).toHaveTextContent('Settings → Connectors → Add custom connector')
      expect(card('Claude Code')).toHaveTextContent('/mcp')
      expect(card('Codex')).toHaveTextContent('codex mcp login loadout')
    })

    it('copies exactly the command a card shows', async () => {
      render(<AgentsIndex {...props()} />)

      await act(async () => {
        fireEvent.click(within(card('Codex')).getByRole('button', { name: /copy/i }))
      })

      expect(writeText).toHaveBeenCalledWith(`codex mcp add loadout --url ${MCP_URL}`)
      expect(within(card('Codex')).getByRole('button', { name: /copied/i })).toBeInTheDocument()
    })

    it('shows the suggested prompt from props and copies it', async () => {
      render(<AgentsIndex {...props()} />)

      expect(screen.getByText(PROMPT)).toBeInTheDocument()
      await act(async () => {
        fireEvent.click(screen.getByRole('button', { name: /copy the prompt/i }))
      })
      expect(writeText).toHaveBeenCalledWith(PROMPT)
    })
  })

  describe('connected marker', () => {
    it('marks a card only when a grant came from an allowlisted host', () => {
      const grants = [
        agent({ id: 'a', name: 'Claude', redirect_host: 'claude.ai', known_key: 'claude' }),
        // Same name as a card, but loopback: it proves nothing.
        agent({ id: 'b', name: 'Claude Code', redirect_host: '127.0.0.1' }),
        agent({ id: 'c', name: 'Cursor', redirect_host: 'cursor://anysphere.cursor-retrieval' }),
      ]
      render(<AgentsIndex {...props(grants)} />)

      expect(within(card('Claude')).getByText('Connected')).toBeInTheDocument()
      for (const name of ['Claude Code', 'Cursor', 'Codex']) {
        expect(within(card(name)).queryByText('Connected')).not.toBeInTheDocument()
      }
    })

    it('marks nothing when no agent is connected', () => {
      render(<AgentsIndex {...props()} />)

      expect(screen.queryByText('Connected')).not.toBeInTheDocument()
    })
  })

  describe('connected agents list', () => {
    it('lists every grant with an initial and its redirect host, and the real mark only for an allowlisted host', () => {
      const grants = [
        agent({ id: 'a', name: 'Claude', redirect_host: 'claude.ai', known_key: 'claude' }),
        agent({ id: 'b', name: 'Claude Code', redirect_host: '127.0.0.1' }),
      ]
      render(<AgentsIndex {...props(grants)} />)

      const [known, unknown] = within(connectedList()).getAllByRole('listitem')
      expect(known).toHaveTextContent('claude.ai')
      expect(known.querySelector('svg')).not.toBeNull()
      expect(unknown).toHaveTextContent('Claude Code')
      expect(unknown).toHaveTextContent('127.0.0.1')
      expect(unknown.querySelector('svg')).toBeNull()
      expect(within(unknown).getByTitle('Claude Code')).toHaveTextContent('C')
    })

    it('says when it was connected and last used', () => {
      const grants = [
        agent({ id: 'a', name: 'Cursor', connected_at: '2020-09-12T12:00:00Z', last_used_at: null }),
        agent({ id: 'b', name: 'Codex', connected_at: '2020-09-03T12:00:00Z', last_used_at: '2020-09-05T12:00:00Z' }),
      ]
      render(<AgentsIndex {...props(grants)} />)

      const [first, second] = within(connectedList()).getAllByRole('listitem')
      expect(first).toHaveTextContent('Sep 12, 2020 · never used')
      expect(second).toHaveTextContent(/Sep 3, 2020 · used Sep 5, 2020/)
    })

    it('says so when nothing is connected', () => {
      render(<AgentsIndex {...props()} />)

      expect(within(connectedList()).getByText(/no agent is connected/i)).toBeInTheDocument()
      expect(within(connectedList()).queryAllByRole('listitem')).toHaveLength(0)
    })
  })

  describe('revoke', () => {
    const revokeButton = (name: string) => screen.getByRole('button', { name: `Revoke ${name}` })

    it('asks first, with the count of suggestions it withdraws, and sends nothing yet', async () => {
      render(<AgentsIndex {...props([agent({ name: 'Cursor', open_suggestions: 2 })])} />)

      await userEvent.click(revokeButton('Cursor'))

      expect(screen.getByText('Revoke Cursor? Its 2 open suggestions are withdrawn.')).toBeInTheDocument()
      expect(screen.getByRole('button', { name: 'Revoke' })).toBeInTheDocument()
      expect(screen.getByRole('button', { name: 'Cancel' })).toHaveFocus()
      expect(del).not.toHaveBeenCalled()
    })

    it('uses the singular for one suggestion and names none when there are none', async () => {
      render(<AgentsIndex {...props([agent({ id: 'a', name: 'Cursor', open_suggestions: 1 }), agent({ id: 'b', name: 'Codex' })])} />)

      await userEvent.click(revokeButton('Cursor'))
      expect(screen.getByText('Revoke Cursor? Its 1 open suggestion is withdrawn.')).toBeInTheDocument()
      await userEvent.click(screen.getByRole('button', { name: 'Cancel' }))

      await userEvent.click(revokeButton('Codex'))
      expect(screen.getByText('Revoke Codex? It has no open suggestions.')).toBeInTheDocument()
    })

    it('cancelling closes the question and puts focus back on that row', async () => {
      render(<AgentsIndex {...props([agent({ id: 'a', name: 'Cursor' }), agent({ id: 'b', name: 'Codex' })])} />)

      await userEvent.click(revokeButton('Codex'))
      await userEvent.click(screen.getByRole('button', { name: 'Cancel' }))

      expect(screen.queryByText(/^Revoke Codex\?/)).not.toBeInTheDocument()
      expect(revokeButton('Codex')).toHaveFocus()
      expect(del).not.toHaveBeenCalled()
    })

    it('Escape cancels the same way', async () => {
      render(<AgentsIndex {...props([agent({ name: 'Cursor' })])} />)

      await userEvent.click(revokeButton('Cursor'))
      await userEvent.keyboard('{Escape}')

      expect(screen.queryByRole('button', { name: 'Cancel' })).not.toBeInTheDocument()
      expect(revokeButton('Cursor')).toHaveFocus()
    })

    it('confirming sends DELETE /agents/:id for that client only', async () => {
      render(<AgentsIndex {...props([agent({ id: 'a b', name: 'Cursor' }), agent({ id: 'b', name: 'Codex' })])} />)

      await userEvent.click(revokeButton('Cursor'))
      await userEvent.click(screen.getByRole('button', { name: 'Revoke' }))

      expect(del).toHaveBeenCalledTimes(1)
      expect(del).toHaveBeenCalledWith('/agents/a%20b', expect.objectContaining({ preserveScroll: true }))
    })

    it('moves focus to the list heading when the revoke finishes, since the row is gone', async () => {
      render(<AgentsIndex {...props([agent({ name: 'Cursor' })])} />)

      await userEvent.click(revokeButton('Cursor'))
      await userEvent.click(screen.getByRole('button', { name: 'Revoke' }))
      act(() => del.mock.calls[0][1].onFinish())

      expect(screen.getByRole('heading', { name: 'Connected agents' })).toHaveFocus()
    })
  })

  describe('WebMCP card', () => {
    it('says a browser agent runs with the member’s session and can click buttons', () => {
      render(<AgentsIndex {...props()} />)

      const webmcp = card('Agent in your browser')
      expect(webmcp).toHaveTextContent(CAPABILITIES.webmcp_note)
      expect(webmcp).toHaveTextContent(/nothing to install or connect/i)
      expect(within(webmcp).getByRole('link', { name: /about webmcp/i })).toHaveAttribute('rel', expect.stringContaining('noopener'))
    })

    it('tells the truth about this browser: no support without a model context', () => {
      render(<AgentsIndex {...props()} />)

      expect(within(card('Agent in your browser')).getByText('This browser does not support WebMCP.')).toBeInTheDocument()
      expect(within(card('Agent in your browser')).getByText(/chrome:\/\/flags\/#enable-webmcp-testing/)).toBeInTheDocument()
    })

    it('says this browser supports it when a model context exists', () => {
      installModelContext()
      render(<AgentsIndex {...props()} />)

      expect(within(card('Agent in your browser')).getByText('This browser supports WebMCP.')).toBeInTheDocument()
      expect(screen.queryByText('This browser does not support WebMCP.')).not.toBeInTheDocument()
    })

    it('also recognises the older navigator.modelContext', () => {
      installModelContext('legacy')
      render(<AgentsIndex {...props()} />)

      expect(screen.getByText('This browser supports WebMCP.')).toBeInTheDocument()
    })
  })

  describe('what it can and can’t do', () => {
    it('lists exactly the lines the server sends', () => {
      render(<AgentsIndex {...props()} />)

      const list = screen.getByRole('region', { name: 'What it can and can’t do' })
      for (const line of [...CAPABILITIES.can, ...CAPABILITIES.cannot]) {
        expect(within(list).getByText(line)).toBeInTheDocument()
      }
      expect(within(list).getAllByRole('listitem')).toHaveLength(CAPABILITIES.can.length + CAPABILITIES.cannot.length)
    })
  })
})
