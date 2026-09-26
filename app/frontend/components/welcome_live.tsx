import { Link } from '@inertiajs/react'
import { useState, type CSSProperties } from 'react'
import { buttonClasses } from './button'
import ConnectAgentCard from './connect_agent_card'
import { LoadoutGlyph } from './wordmark'

const BURST_COLORS = ['#1652ea', '#8cff8a', '#ff7765', '#c0f0fb', '#121212']

function Burst() {
  return (
    <span aria-hidden="true" className="pointer-events-none absolute left-1/2 top-1/2">
      {Array.from({ length: 14 }, (_, i) => {
        const angle = (i / 14) * Math.PI * 2
        const distance = 70 + (i % 3) * 26
        const style = {
          '--burst-x': `${Math.cos(angle) * distance}px`,
          '--burst-y': `${Math.sin(angle) * distance}px`,
          '--burst-r': `${(i % 2 ? 1 : -1) * (90 + i * 20)}deg`,
          background: BURST_COLORS[i % BURST_COLORS.length],
          animationDelay: `${120 + (i % 4) * 40}ms`,
        } as CSSProperties
        return <span key={i} style={style} className="animate-burst absolute h-2 w-3.5 rounded-full" />
      })}
    </span>
  )
}

export function profileUrl(handle: string) {
  const origin = typeof window === 'undefined' ? 'https://loadout.every.to' : window.location.origin
  return `${origin}/${handle}`
}

/**
 * The "you're live" moment at the end of onboarding: the link, share actions,
 * and "Connect your agent". The profile page renders it when flash.welcome is set.
 */
export default function WelcomeLive({ handle, firstName, isPublic }: { handle: string; firstName?: string | null; isPublic: boolean }) {
  const [copied, setCopied] = useState(false)
  const url = profileUrl(handle)
  const display = url.replace(/^https?:\/\//, '')
  const shareText = 'What’s in my AI loadout: the tools and models I actually use.'

  const copy = async () => {
    try {
      await navigator.clipboard.writeText(url)
      setCopied(true)
      window.setTimeout(() => setCopied(false), 1800)
    } catch {
      setCopied(false)
    }
  }

  return (
    <div className="grid gap-5 md:grid-cols-[1.35fr_1fr]">
      <section className="card relative overflow-hidden p-6 sm:p-8" aria-labelledby="welcome-live-title">
        <div className="relative inline-flex h-14 w-14 items-center justify-center rounded-2xl bg-paper-deep">
          <Burst />
          <LoadoutGlyph className="animate-slot h-8 w-8 text-ink" />
        </div>
        <p className="eyebrow mt-6">You're live</p>
        <h2 id="welcome-live-title" className="display mt-2 text-4xl sm:text-5xl">
          {firstName ? `Nice, ${firstName}.` : 'Nice.'} Your loadout exists.
        </h2>

        <div className="mt-6 flex flex-col gap-3 sm:flex-row sm:items-center">
          <span className="min-w-0 flex-1 truncate rounded-full border border-rule bg-paper px-4 py-2.5 font-mono text-sm text-ink">
            {display}
          </span>
          <div className="flex gap-2">
            <button type="button" onClick={copy} className={buttonClasses('primary')}>
              {copied ? 'Copied' : 'Copy link'}
            </button>
            {isPublic && (
              <a
                href={`https://x.com/intent/post?text=${encodeURIComponent(shareText)}&url=${encodeURIComponent(url)}`}
                target="_blank"
                rel="noreferrer"
                className={buttonClasses('secondary')}
              >
                Share on X
              </a>
            )}
          </div>
        </div>

        {isPublic ? (
          <p className="mt-4 text-sm text-ink-muted">Public: anyone with the link can see it, no sign-in needed.</p>
        ) : (
          <div className="mt-5 flex flex-col gap-3 rounded-2xl bg-paper-deep p-4 sm:flex-row sm:items-center sm:justify-between">
            <p className="text-sm text-ink-soft">Private for now. Only you can see this page.</p>
            <Link
              href="/settings"
              method="patch"
              data={{ public: true }}
              as="button"
              preserveScroll
              className={buttonClasses('blue')}
            >
              Make it public
            </Link>
          </div>
        )}
      </section>
      <ConnectAgentCard compact />
    </div>
  )
}
