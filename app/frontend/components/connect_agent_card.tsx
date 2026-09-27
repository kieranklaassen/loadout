import { useState } from 'react'
import { ButtonLink } from './button'
import SectionLabel from './section_label'

export const AGENT_PROMPT = 'Fill in my Loadout from what you know about how I work.'

const CLIENTS = ['Claude', 'Claude Code', 'Cursor', 'Codex']

/** "Connect your agent": the equal alternative to filling in the picks by hand. */
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
    <section className={`panel p-6 md:p-7 ${className}`}>
      <SectionLabel as="p">Or let your agent do it</SectionLabel>
      <h3 className="display mt-2 text-3xl">Connect your agent</h3>
      <p className="mt-2 max-w-md text-sm text-fg-soft">
        Add Loadout to {CLIENTS.slice(0, -1).join(', ')} or {CLIENTS[CLIENTS.length - 1]}. It signs in with Every and suggests picks. Nothing
        shows on your page until you confirm it.
      </p>
      {!compact && (
        <button
          type="button"
          onClick={copy}
          className="mt-5 block w-full rounded-sharp border border-line-strong bg-field px-4 py-3 text-left transition-colors hover:border-fg-muted"
        >
          <SectionLabel>{copied ? 'Copied' : 'Suggested prompt · tap to copy'}</SectionLabel>
          <span className="mt-1 block font-serif text-lg italic">“{AGENT_PROMPT}”</span>
        </button>
      )}
      <ButtonLink href="/agents" variant="secondary" className="mt-5">
        Set up an agent
        <span aria-hidden="true">→</span>
      </ButtonLink>
    </section>
  )
}
