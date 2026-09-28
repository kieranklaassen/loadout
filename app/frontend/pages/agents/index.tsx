import { Head, router } from '@inertiajs/react'
import { useEffect, useId, useRef, useState, type KeyboardEvent, type ReactNode } from 'react'
import AppShell from '../../components/app_shell'
import Button, { buttonClasses } from '../../components/button'
import CapabilityLists, { type Capabilities } from '../../components/capabilities'
import Mark from '../../components/mark'
import SectionLabel from '../../components/section_label'
import { getModelContext } from '../../lib/webmcp'
import { relativeDate, shortDate } from '../../lib/relative_date'

/** One connected client, as `AgentsController#index` sends it. `known_key` is set only for an https redirect on an allowlisted host. */
type Agent = {
  id: string
  name: string
  redirect_host: string
  known_key: string | null
  open_suggestions: number
  connected_at: string
  last_used_at: string | null
}

type Props = {
  agents: Agent[]
  capabilities: Capabilities
  mcp_url: string
  cursor_install_url: string
  suggested_prompt: string
}

/** The product cards. `key` is what the server's `known_key` names; `mark` is the file in assets/marks. */
const PRODUCTS = [
  { key: 'claude_code', name: 'Claude Code', mark: 'claudecode' },
  { key: 'claude', name: 'Claude', mark: 'claude' },
  { key: 'cursor', name: 'Cursor', mark: 'cursor' },
  { key: 'codex', name: 'Codex', mark: 'openai' },
] as const

const WEBMCP_SPEC_URL = 'https://webmachinelearning.github.io/webmcp/'
const WEBMCP_FLAG = 'chrome://flags/#enable-webmcp-testing'

const heading = 'font-serif leading-[1.02] tracking-[-0.02em] text-[28px] md:text-[30px]'
const panelPadding = 'px-5 py-5 md:px-[22px]'
const monoWell = 'mt-3.5 rounded-sharp bg-page px-3.5 py-3 font-mono text-caption leading-relaxed text-fg [overflow-wrap:anywhere]'
const caption = 'mt-3 text-caption leading-normal text-fg-soft'
const code = 'font-mono text-fg'

function CopyButton({ text, what }: { text: string; what: string }) {
  const [copied, setCopied] = useState(false)

  const copy = async () => {
    try {
      await navigator.clipboard.writeText(text)
      setCopied(true)
      window.setTimeout(() => setCopied(false), 1600)
    } catch {
      setCopied(false)
    }
  }

  return (
    <button
      type="button"
      onClick={copy}
      aria-label={`${copied ? 'Copied' : 'Copy'} ${what}`}
      className="text-link flex min-h-11 shrink-0 items-center text-caption text-fg-soft md:min-h-0"
    >
      {copied ? 'Copied' : 'Copy'}
    </button>
  )
}

function ProductCard({
  name,
  mark,
  connected,
  copy,
  children,
}: {
  name: string
  mark: string
  connected: boolean
  copy?: { text: string; what: string }
  children: ReactNode
}) {
  const headingId = useId()

  return (
    <section aria-labelledby={headingId} className={`panel ${panelPadding}`}>
      <div className="flex items-center gap-3">
        <Mark item={{ name, kind: 'tool', mark }} />
        <h3 id={headingId} className="text-[17px] font-semibold">
          {name}
        </h3>
        <span className="flex-1" />
        {connected && <span className="font-mono text-xs uppercase tracking-[0.08em] text-fg">Connected</span>}
        {copy && <CopyButton text={copy.text} what={copy.what} />}
      </div>
      {children}
    </section>
  )
}

function ProductCards({ agents, mcpUrl, cursorInstallUrl }: { agents: Agent[]; mcpUrl: string; cursorInstallUrl: string }) {
  const connected = new Set(agents.map((agent) => agent.known_key))
  const claudeCode = `claude mcp add --transport http toolbox ${mcpUrl}`
  const cursorJson = JSON.stringify({ mcpServers: { toolbox: { url: mcpUrl } } })
  const codex = `codex mcp add toolbox --url ${mcpUrl}`

  const card = (key: (typeof PRODUCTS)[number]['key'], copy: string, body: ReactNode) => {
    const product = PRODUCTS.find((entry) => entry.key === key)!
    return (
      <ProductCard name={product.name} mark={product.mark} connected={connected.has(key)} copy={{ text: copy, what: `the ${product.name} setup` }}>
        {body}
      </ProductCard>
    )
  }

  return (
    <>
      {card(
        'claude_code',
        claudeCode,
        <>
          <div className={monoWell}>{claudeCode}</div>
          <p className={caption}>
            Then run <code className={code}>/mcp</code> in Claude Code, pick toolbox, and sign in with Every.
          </p>
        </>,
      )}
      {card(
        'claude',
        mcpUrl,
        <>
          <div className={monoWell}>
            <p className="font-sans text-fg-soft">Settings → Connectors → Add custom connector</p>
            <p className="mt-1.5">{mcpUrl}</p>
          </div>
          <p className={caption}>Name it Toolbox, paste the URL, then select Connect and approve.</p>
        </>,
      )}
      {card(
        'cursor',
        cursorJson,
        <>
          <a href={cursorInstallUrl} className={`${buttonClasses('secondary')} mt-3.5`}>
            Add to Cursor
          </a>
          <div className={monoWell}>{cursorJson}</div>
          <p className={caption}>
            Or add that to <code className={code}>~/.cursor/mcp.json</code>, then select Connect next to toolbox in Cursor Settings → MCP.
          </p>
        </>,
      )}
      {card(
        'codex',
        codex,
        <>
          <div className={monoWell}>{codex}</div>
          <p className={caption}>
            Then run <code className={code}>codex mcp login toolbox</code> and approve in the browser.
          </p>
        </>,
      )}
    </>
  )
}

function WebmcpCard({ note }: { note: string }) {
  const headingId = useId()
  // Read after mount: the browser's model context does not exist on the server.
  const [supported, setSupported] = useState<boolean | null>(null)
  useEffect(() => setSupported(getModelContext() !== null), [])

  return (
    <section aria-labelledby={headingId} className={`panel md:col-span-2 ${panelPadding}`}>
      <div className="flex items-center gap-3">
        <Mark item={{ name: 'WebMCP', kind: 'tool', mark: null }} />
        <h3 id={headingId} className="text-[17px] font-semibold">
          Agent in your browser
        </h3>
        <SectionLabel className="text-fg!">WebMCP</SectionLabel>
      </div>
      <p className="mt-3 max-w-[640px] text-[15px] leading-normal text-fg-soft">
        Toolbox supports WebMCP. While you are signed in, a browser agent that supports it can use the same tools on this site. There is
        nothing to install or connect, and its picks stay suggestions until you confirm them.
      </p>
      <p className="mt-3 max-w-[640px] text-[15px] leading-normal text-fg">{note}</p>
      <p className={`${caption} max-w-[640px]`}>
        To try it, open Toolbox in a browser with WebMCP turned on. In Chrome, that is <code className={code}>{WEBMCP_FLAG}</code>.{' '}
        <a href={WEBMCP_SPEC_URL} target="_blank" rel="noopener noreferrer" className="text-link">
          About WebMCP
        </a>
      </p>
      {supported !== null && (
        <p className="mt-3 font-mono text-caption text-fg">{supported ? 'This browser supports WebMCP.' : 'This browser does not support WebMCP.'}</p>
      )}
    </section>
  )
}

function AgentRow({ agent, onRevoked }: { agent: Agent; onRevoked: () => void }) {
  const [confirming, setConfirming] = useState(false)
  const revokeRef = useRef<HTMLButtonElement>(null)
  const cancelRef = useRef<HTMLButtonElement>(null)
  const wasConfirming = useRef(false)
  const product = PRODUCTS.find((entry) => entry.key === agent.known_key)
  const suggestions = agent.open_suggestions

  // Moving into the question lands on the safe choice; leaving it lands back on the row's Revoke.
  useEffect(() => {
    if (confirming === wasConfirming.current) return
    wasConfirming.current = confirming
    ;(confirming ? cancelRef : revokeRef).current?.focus()
  }, [confirming])

  const revoke = () => router.delete(`/agents/${encodeURIComponent(agent.id)}`, { preserveScroll: true, onFinish: onRevoked })
  const onKeyDown = (event: KeyboardEvent) => {
    if (event.key === 'Escape') setConfirming(false)
  }

  return (
    <li className="border-b border-line py-3.5" onKeyDown={onKeyDown}>
      <div className="flex items-center gap-3.5">
        <Mark item={{ name: agent.name, kind: 'tool', mark: product?.mark ?? null }} />
        <div className="min-w-0 flex-1">
          <p className="truncate text-[15px] font-semibold">{agent.name}</p>
          <p className="font-mono text-caption text-fg-muted [overflow-wrap:anywhere]">{agent.redirect_host}</p>
          <p className="font-mono text-caption text-fg-muted">
            {shortDate(agent.connected_at)} · {agent.last_used_at ? `used ${relativeDate(agent.last_used_at)}` : 'never used'}
          </p>
        </div>
        {!confirming && (
          <Button ref={revokeRef} variant="secondary" className="text-coral!" aria-label={`Revoke ${agent.name}`} onClick={() => setConfirming(true)}>
            Revoke
          </Button>
        )}
      </div>
      {confirming && (
        <div className="mt-3">
          <p className="text-[15px] leading-normal text-fg [overflow-wrap:anywhere]">
            {suggestions > 0
              ? `Revoke ${agent.name}? Its ${suggestions} open ${suggestions === 1 ? 'suggestion is' : 'suggestions are'} withdrawn.`
              : `Revoke ${agent.name}? It has no open suggestions.`}
          </p>
          <div className="mt-3 flex gap-2">
            <Button variant="danger" onClick={revoke}>
              Revoke
            </Button>
            <Button ref={cancelRef} variant="secondary" onClick={() => setConfirming(false)}>
              Cancel
            </Button>
          </div>
        </div>
      )}
    </li>
  )
}

function ConnectedAgents({ agents }: { agents: Agent[] }) {
  const headingRef = useRef<HTMLHeadingElement>(null)

  return (
    <section aria-labelledby="connected-heading" className="mt-9">
      <h2 id="connected-heading" ref={headingRef} tabIndex={-1} className={heading}>
        Connected agents
      </h2>
      <p className="mt-2 text-caption leading-normal text-fg-muted">Revoking stops it reading or changing your toolbox.</p>
      {agents.length === 0 ? (
        <p className="mt-3 border-t border-line-strong pt-4 text-[15px] text-fg-soft">No agent is connected. Set one up and it will show here.</p>
      ) : (
        <ul className="mt-3 border-t border-line-strong">
          {agents.map((agent) => (
            <AgentRow key={agent.id} agent={agent} onRevoked={() => headingRef.current?.focus()} />
          ))}
        </ul>
      )}
    </section>
  )
}

export default function AgentsIndex({ agents, capabilities, mcp_url, cursor_install_url, suggested_prompt }: Props) {
  return (
    <AppShell>
      <Head title="Agents" />
      <div className="flex flex-col gap-12 pt-4 xl:flex-row xl:gap-[72px]">
        <div className="min-w-0 max-w-[760px] flex-1">
          <h1 className="font-serif leading-[1.02] tracking-[-0.02em] text-[40px] md:text-[56px]">Let your agent fill it in</h1>
          <p className="mt-4 max-w-[760px] text-lg leading-normal text-fg-soft">
            Connect Claude, Claude Code, Cursor or Codex with your normal Every sign-in, or use an agent in your browser through WebMCP.
            There are no keys to paste. Your agent proposes picks from what it knows about how you work.
          </p>

          <div className={`panel mt-7 ${panelPadding}`}>
            <div className="flex items-center justify-between gap-3">
              <SectionLabel className="text-fg-soft!">Then ask it</SectionLabel>
              <CopyButton text={suggested_prompt} what="the prompt" />
            </div>
            <p className="mt-2 font-serif text-2xl leading-snug">{suggested_prompt}</p>
          </div>

          <div className="mt-7 grid grid-cols-1 gap-4 md:grid-cols-2">
            <ProductCards agents={agents} mcpUrl={mcp_url} cursorInstallUrl={cursor_install_url} />
            <WebmcpCard note={capabilities.webmcp_note} />
          </div>
        </div>

        <aside className="w-full max-w-[760px] xl:w-[400px] xl:flex-none">
          <section aria-labelledby="capabilities-heading" className="panel p-6">
            <h2 id="capabilities-heading" className={heading}>
              What it can and can’t do
            </h2>
            <CapabilityLists capabilities={capabilities} />
          </section>
          <ConnectedAgents agents={agents} />
        </aside>
      </div>
    </AppShell>
  )
}
