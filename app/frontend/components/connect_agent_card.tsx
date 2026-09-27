import { Link } from '@inertiajs/react'
import { useState } from 'react'

export const AGENT_PROMPT = 'Fill in my Loadout from what you know about how I work.'

const CLIENTS = ['Claude', 'Claude Code', 'Cursor', 'Codex']

/** "Connect your agent": the equal alternative to tapping through the picker. */
export default function ConnectAgentCard({ className = '', compact = false }: { className?: string; compact?: boolean }) {
  const [copied, setCopied] = useState(false)

  const copy = async () => {
    try {
      await navigator.clipboard.writeText(AGENT_PROMPT)
      setCopied(true)
      window.setTimeout(() => setCopied(false), 1800)
    } catch {
      setCopied(false)
    }
  }

  return (
    <section className={`relative overflow-hidden rounded-[var(--radius-card)] bg-ink p-6 text-paper sm:p-7 ${className}`}>
      <div aria-hidden="true" className="pointer-events-none absolute -right-10 -top-10 h-40 w-40 rounded-full bg-every-blue/40 blur-3xl" />
      <p className="eyebrow !text-paper/60">Or let your agent do it</p>
      <h3 className="display mt-2 text-3xl">Connect your agent</h3>
      <p className="mt-2 max-w-md text-sm text-paper/75">
        Add Loadout to {CLIENTS.slice(0, -1).join(', ')} or {CLIENTS[CLIENTS.length - 1]}. It signs in with Every, then keeps your loadout current
        whenever you ask.
      </p>
      {!compact && (
        <button
          type="button"
          onClick={copy}
          className="mt-5 block w-full rounded-2xl border border-paper/15 bg-paper/5 px-4 py-3 text-left transition hover:bg-paper/10"
        >
          <span className="eyebrow !text-paper/50">{copied ? 'Copied' : 'Suggested prompt · tap to copy'}</span>
          <span className="mt-1 block font-serif text-lg italic">“{AGENT_PROMPT}”</span>
        </button>
      )}
      <Link
        href="/agents"
        className="mt-5 inline-flex items-center gap-2 rounded-full bg-paper px-4 py-2.5 text-sm font-medium text-ink transition hover:bg-every-sky"
      >
        Set up an agent
        <span aria-hidden="true">→</span>
      </Link>
    </section>
  )
}
