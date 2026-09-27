import { Head, router } from '@inertiajs/react'
import { useState, type ReactNode } from 'react'
import AppShell from '../../components/app_shell'
import Button, { buttonClasses } from '../../components/button'
import ToolMark from '../../components/tool_mark'
import type { ConnectedAgent } from '../../types'

type AgentsProps = {
  agents: ConnectedAgent[]
  mcp_url: string
  cursor_install_url: string
  suggested_prompt: string
}

type ClientKey = 'claude' | 'claude_code' | 'cursor' | 'codex'

const CLIENTS: { key: ClientKey; label: string }[] = [
  { key: 'claude', label: 'Claude' },
  { key: 'claude_code', label: 'Claude Code' },
  { key: 'cursor', label: 'Cursor' },
  { key: 'codex', label: 'Codex' },
]

const DATE = new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric', year: 'numeric' })

export function timeAgo(iso: string, now: Date = new Date()) {
  const seconds = Math.max(0, Math.round((now.getTime() - new Date(iso).getTime()) / 1000))
  if (seconds < 60) return 'just now'
  const minutes = Math.round(seconds / 60)
  if (minutes < 60) return `${minutes} min ago`
  const hours = Math.round(minutes / 60)
  if (hours < 24) return `${hours} hr ago`
  const days = Math.round(hours / 24)
  if (days < 30) return `${days} day${days === 1 ? '' : 's'} ago`
  return DATE.format(new Date(iso))
}

function CopyButton({ text, label = 'Copy', tone = 'light' }: { text: string; label?: string; tone?: 'light' | 'dark' }) {
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
      aria-label={`${label}: ${text}`}
      className={`shrink-0 rounded-full px-3 py-1.5 font-sans text-xs font-medium ring-1 transition ${
        tone === 'dark' ? 'text-paper/80 ring-paper/25 hover:text-paper hover:ring-paper/60' : 'text-ink-soft ring-rule hover:text-ink hover:ring-ink/30'
      }`}
    >
      {copied ? 'Copied' : label}
    </button>
  )
}

function Snippet({ code, label }: { code: string; label?: string }) {
  return (
    <div className="mt-3 flex items-start gap-3 rounded-xl bg-ink px-4 py-3 text-paper">
      <pre className="min-w-0 flex-1 overflow-x-auto whitespace-pre font-mono text-[0.8rem] leading-relaxed">{code}</pre>
      <CopyButton text={code} label={label} tone="dark" />
    </div>
  )
}

function Step({ n, children }: { n: number; children: ReactNode }) {
  return (
    <li className="flex gap-4">
      <span className="mt-0.5 inline-flex h-6 w-6 shrink-0 items-center justify-center rounded-full border border-rule font-mono text-[0.7rem] text-ink-muted">
        {n}
      </span>
      <div className="min-w-0 flex-1 text-[0.95rem] text-ink-soft">{children}</div>
    </li>
  )
}

function Instructions({ client, mcpUrl, cursorInstallUrl }: { client: ClientKey; mcpUrl: string; cursorInstallUrl: string }) {
  switch (client) {
    case 'claude':
      return (
        <ol className="space-y-4">
          <Step n={1}>
            In Claude (claude.ai or the desktop app), open <b className="font-medium text-ink">Settings → Connectors</b>.
          </Step>
          <Step n={2}>
            Choose <b className="font-medium text-ink">Add custom connector</b>, name it Loadout, and paste the URL above.
          </Step>
          <Step n={3}>Select Connect, sign in with Every, and approve.</Step>
        </ol>
      )
    case 'claude_code':
      return (
        <ol className="space-y-4">
          <Step n={1}>
            Add the server from your terminal:
            <Snippet code={`claude mcp add --transport http loadout ${mcpUrl}`} />
          </Step>
          <Step n={2}>
            In Claude Code, run <code className="font-mono text-[0.85rem] text-ink">/mcp</code>, pick loadout, and sign in with Every.
          </Step>
        </ol>
      )
    case 'cursor':
      return (
        <ol className="space-y-4">
          <Step n={1}>
            <a href={cursorInstallUrl} className={`${buttonClasses('primary')} mt-[-2px]`}>
              Add to Cursor
            </a>
            <p className="mt-3">Or add it to <code className="font-mono text-[0.85rem] text-ink">~/.cursor/mcp.json</code> yourself:</p>
            <Snippet code={JSON.stringify({ mcpServers: { loadout: { url: mcpUrl } } }, null, 2)} />
          </Step>
          <Step n={2}>In Cursor Settings → MCP, select Connect next to loadout and approve in the browser.</Step>
        </ol>
      )
    case 'codex':
      return (
        <ol className="space-y-4">
          <Step n={1}>
            Add the server:
            <Snippet code={`codex mcp add loadout --url ${mcpUrl}`} />
            <p className="mt-3">
              Or put it in <code className="font-mono text-[0.85rem] text-ink">~/.codex/config.toml</code>:
            </p>
            <Snippet code={`[mcp_servers.loadout]\nurl = "${mcpUrl}"`} />
          </Step>
          <Step n={2}>
            Run <code className="font-mono text-[0.85rem] text-ink">codex mcp login loadout</code> and approve in the browser.
          </Step>
        </ol>
      )
    default: {
      const unreachable: never = client
      return unreachable
    }
  }
}

function AgentRow({ agent }: { agent: ConnectedAgent }) {
  const revoke = () => {
    if (window.confirm(`Disconnect ${agent.name}? Its next request will be refused until you approve it again.`)) {
      router.delete(`/agents/${encodeURIComponent(agent.id)}`, { preserveScroll: true })
    }
  }

  return (
    <li className="flex items-center gap-4 py-4">
      <ToolMark item={agent} size="md" />
      <div className="min-w-0 flex-1">
        <p className="truncate font-medium text-ink">{agent.name}</p>
        <p className="mt-0.5 text-sm text-ink-muted">
          Connected {DATE.format(new Date(agent.connected_at))}
          <span aria-hidden="true"> · </span>
          {agent.last_used_at ? `Last used ${timeAgo(agent.last_used_at)}` : 'Not used yet'}
        </p>
      </div>
      <Button variant="secondary" onClick={revoke}>
        Revoke
      </Button>
    </li>
  )
}

export default function AgentsIndex({ agents, mcp_url, cursor_install_url, suggested_prompt }: AgentsProps) {
  const [client, setClient] = useState<ClientKey>('claude')

  return (
    <AppShell>
      <Head title="Agents" />
      <header className="max-w-2xl animate-rise">
        <p className="eyebrow">Agents</p>
        <h1 className="display mt-3 text-5xl text-balance">Let your agent keep your Loadout current.</h1>
        <p className="mt-4 text-lg text-ink-soft">
          Connect Claude, Claude Code, Cursor, or Codex once. It signs in with Every, asks you before it guesses, and every change it
          makes shows up with its name.
        </p>
      </header>

      <section aria-labelledby="connected-heading" className="mt-14">
        <div className="flex items-baseline justify-between border-b border-rule pb-3">
          <h2 id="connected-heading" className="display text-2xl">
            Connected agents
          </h2>
          <span className="font-mono text-xs text-ink-muted">{agents.length}</span>
        </div>
        {agents.length === 0 ? (
          <p className="py-6 text-ink-muted">No agents yet. Connect one below and it will show up here.</p>
        ) : (
          <ul className="divide-y divide-rule">
            {agents.map((agent) => (
              <AgentRow key={agent.id} agent={agent} />
            ))}
          </ul>
        )}
      </section>

      <section aria-labelledby="connect-heading" className="mt-14">
        <h2 id="connect-heading" className="display border-b border-rule pb-3 text-2xl">
          Connect your agent
        </h2>

        <div className="mt-8 grid gap-8 lg:grid-cols-[minmax(0,1fr)_20rem]">
          <div className="card p-6 sm:p-8">
            <p className="eyebrow">MCP server URL</p>
            <div className="mt-3 flex items-center gap-3 rounded-xl border border-rule bg-paper px-4 py-3">
              <code className="min-w-0 flex-1 truncate font-mono text-[0.95rem] text-ink">{mcp_url}</code>
              <CopyButton text={mcp_url} />
            </div>

            <div role="tablist" aria-label="Choose your agent" className="mt-8 flex flex-wrap gap-1.5">
              {CLIENTS.map(({ key, label }) => (
                <button
                  key={key}
                  type="button"
                  role="tab"
                  aria-selected={client === key}
                  onClick={() => setClient(key)}
                  className={`rounded-full px-4 py-2 text-sm transition ${
                    client === key ? 'bg-ink text-paper' : 'text-ink-soft ring-1 ring-rule hover:text-ink hover:ring-ink/30'
                  }`}
                >
                  {label}
                </button>
              ))}
            </div>
            <div role="tabpanel" className="mt-6">
              <Instructions client={client} mcpUrl={mcp_url} cursorInstallUrl={cursor_install_url} />
            </div>
          </div>

          <aside className="self-start rounded-2xl bg-every-sky/45 p-6">
            <p className="eyebrow text-ink-soft">Then ask it</p>
            <blockquote className="display mt-3 text-2xl leading-snug">“{suggested_prompt}”</blockquote>
            <div className="mt-5">
              <CopyButton text={suggested_prompt} label="Copy prompt" />
            </div>
          </aside>
        </div>
      </section>
    </AppShell>
  )
}
