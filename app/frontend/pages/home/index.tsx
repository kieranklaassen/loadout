import { Head, Link } from '@inertiajs/react'
import Avatar from '../../components/avatar'
import { buttonClasses } from '../../components/button'
import ToolMark from '../../components/tool_mark'
import Wordmark from '../../components/wordmark'
import type { CatalogItem } from '../../types'

type FeaturedPick = { category: string; tool: CatalogItem; model: CatalogItem | null }
type Featured = { handle: string; name: string; avatar_url: string | null; picks: FeaturedPick[] }

interface HomeProps {
  stats?: { members: number; picks: number; tools: number }
  featured?: Featured[]
}

const EXAMPLE: FeaturedPick[] = [
  { category: 'Coding', tool: { slug: 'claude-code', name: 'Claude Code', maker: 'Anthropic', hue: 18, monogram: 'CC' }, model: { slug: 'claude-opus-5-5', name: 'Claude Opus 5.5', maker: 'Anthropic', hue: 18, monogram: 'O5' } },
  { category: 'Knowledge work', tool: { slug: 'claude', name: 'Claude', maker: 'Anthropic', hue: 18, monogram: 'Cl' }, model: null },
  { category: 'Video', tool: { slug: 'runway', name: 'Runway', maker: 'Runway', hue: 345, monogram: 'Rw' }, model: { slug: 'runway-gen-4-5', name: 'Runway Gen-4.5', maker: 'Runway', hue: 345, monogram: 'R4' } },
  { category: 'Speech to text', tool: { slug: 'monologue', name: 'Monologue', maker: 'Every', hue: 300, monogram: 'Mo' }, model: null },
]

const CATEGORIES = ['Coding', 'Knowledge work', 'Writing', 'Research', 'Classification', 'Image', 'Video', 'Animation', 'Text to speech', 'Speech to text', 'Music']

const STEPS = [
  { title: 'Sign in with Every', body: 'Use your every.to account. No passwords, no forms.' },
  { title: 'Claim your link', body: 'loadout.every.to/you. Private until you say otherwise.' },
  { title: 'Tap what you use', body: 'Pick tools and models per task in about a minute, or let your agent fill it in.' },
]

function ExampleCard({ name, handle, avatar, picks }: { name: string; handle: string; avatar: string | null; picks: FeaturedPick[] }) {
  return (
    <div className="card relative overflow-hidden p-6 sm:p-8">
      <div className="flex items-center gap-4">
        <Avatar name={name} src={avatar} size="lg" />
        <div className="min-w-0">
          <p className="display truncate text-3xl">{name}</p>
          <p className="font-mono text-xs text-ink-muted">loadout.every.to/{handle}</p>
        </div>
      </div>
      <ul className="mt-6 divide-y divide-rule border-t border-rule">
        {picks.map((pick) => (
          <li key={pick.category} className="flex items-center gap-4 py-3.5">
            <span className="eyebrow w-28 shrink-0 sm:w-32">{pick.category}</span>
            <ToolMark item={pick.tool} size="sm" />
            <span className="min-w-0 flex-1 truncate font-medium">{pick.tool.name}</span>
            {pick.model && (
              <span className="hidden truncate rounded-full bg-paper-deep px-2.5 py-1 text-xs text-ink-soft sm:inline">{pick.model.name}</span>
            )}
          </li>
        ))}
      </ul>
    </div>
  )
}

export default function Home({ stats, featured = [] }: HomeProps) {
  const hero = featured[0]

  return (
    <>
      <Head title="What's in your AI loadout?" />
      <div className="flex min-h-screen flex-col">
        <header className="mx-auto flex w-full max-w-6xl items-center justify-between px-5 py-6 sm:px-8">
          <Wordmark />
          <a href="/auth/every" className={buttonClasses('secondary')}>
            Sign in
          </a>
        </header>

        <main className="flex-1">
          <section className="mx-auto grid max-w-6xl items-center gap-12 px-5 pb-20 pt-10 sm:px-8 lg:grid-cols-[1.1fr_1fr] lg:pt-16">
            <div className="animate-rise">
              <p className="eyebrow">Made at Every</p>
              <h1 className="display mt-4 text-6xl sm:text-7xl lg:text-[5.5rem]">
                What's in your <em className="italic text-every-blue">AI loadout?</em>
              </h1>
              <p className="mt-6 max-w-xl text-xl leading-relaxed text-ink-soft">
                One page for the tools and models you actually use, per task. See what your colleagues reach for, and notice
                when you're a model behind.
              </p>
              <div className="mt-9 flex flex-wrap items-center gap-4">
                <a href="/auth/every" className={buttonClasses('primary', 'lg')}>
                  Claim your link
                </a>
                <span className="font-mono text-sm text-ink-muted">loadout.every.to/you</span>
              </div>
              {stats && stats.members > 0 && (
                <p className="mt-10 text-sm text-ink-muted">
                  <span className="font-medium text-ink">{stats.members.toLocaleString()}</span> people ·{' '}
                  <span className="font-medium text-ink">{stats.picks.toLocaleString()}</span> picks ·{' '}
                  <span className="font-medium text-ink">{stats.tools.toLocaleString()}</span> tools in the catalog
                </p>
              )}
            </div>
            <div className="animate-rise [animation-delay:120ms] lg:rotate-[1.2deg]">
              {hero ? (
                <Link href={`/${hero.handle}`} className="block transition hover:-translate-y-0.5">
                  <ExampleCard name={hero.name} handle={hero.handle} avatar={hero.avatar_url} picks={hero.picks} />
                </Link>
              ) : (
                <ExampleCard name="Kieran Klaassen" handle="kieran" avatar={null} picks={EXAMPLE} />
              )}
            </div>
          </section>

          <section className="border-y border-rule bg-white/60">
            <div className="mx-auto max-w-6xl px-5 py-6 sm:px-8">
              <ul className="flex flex-wrap gap-x-6 gap-y-2 font-serif text-lg text-ink-soft">
                {CATEGORIES.map((category) => (
                  <li key={category}>{category}</li>
                ))}
              </ul>
            </div>
          </section>

          <section className="mx-auto max-w-6xl px-5 py-20 sm:px-8">
            <p className="eyebrow">How it works</p>
            <ol className="mt-8 grid gap-10 sm:grid-cols-3">
              {STEPS.map((step, index) => (
                <li key={step.title}>
                  <span className="font-mono text-sm text-every-blue">0{index + 1}</span>
                  <h2 className="display mt-3 text-3xl">{step.title}</h2>
                  <p className="mt-3 text-ink-soft">{step.body}</p>
                </li>
              ))}
            </ol>
          </section>

          <section className="mx-auto max-w-6xl px-5 pb-20 sm:px-8">
            <div className="grid gap-10 rounded-[2rem] bg-ink p-8 text-paper sm:p-12 lg:grid-cols-2">
              <div>
                <p className="eyebrow !text-paper/60">Let your agent do it</p>
                <h2 className="display mt-4 text-4xl sm:text-5xl">Your agent already knows your stack.</h2>
                <p className="mt-5 text-lg text-paper/75">
                  Connect Claude, Claude Code, Cursor, or Codex over MCP with a normal sign-in. Ask it to fill in your loadout,
                  and to keep it current when you switch.
                </p>
              </div>
              <div className="self-center rounded-2xl bg-white/5 p-6 font-mono text-sm leading-relaxed ring-1 ring-white/10">
                <p className="text-paper/50">$ claude mcp add --transport http loadout https://loadout.every.to/mcp</p>
                <p className="mt-5 text-paper/50">&gt; Fill in my Loadout from what you know about how I work.</p>
                <p className="mt-3 text-every-lime">✓ Added Claude Code with Claude Opus 5.5 for coding</p>
                <p className="text-every-lime">✓ Added Monologue for speech to text</p>
              </div>
            </div>
          </section>

          {featured.length > 1 && (
            <section className="mx-auto max-w-6xl px-5 pb-24 sm:px-8">
              <p className="eyebrow">Recently updated</p>
              <ul className="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                {featured.slice(1).map((person) => (
                  <li key={person.handle}>
                    <Link href={`/${person.handle}`} className="card flex items-center gap-4 p-5 transition hover:shadow-[var(--shadow-lift)]">
                      <Avatar name={person.name} src={person.avatar_url} />
                      <div className="min-w-0 flex-1">
                        <p className="truncate font-medium">{person.name}</p>
                        <div className="mt-1.5 flex gap-1">
                          {person.picks.map((pick) => (
                            <ToolMark key={pick.category} item={pick.tool} size="xs" />
                          ))}
                        </div>
                      </div>
                    </Link>
                  </li>
                ))}
              </ul>
            </section>
          )}
        </main>

        <footer className="border-t border-rule">
          <div className="mx-auto flex max-w-6xl flex-col gap-2 px-5 py-8 text-sm text-ink-muted sm:flex-row sm:justify-between sm:px-8">
            <span>
              Loadout is made at{' '}
              <a href="https://every.to" className="underline decoration-rule underline-offset-4 hover:text-ink">
                Every
              </a>
              .
            </span>
            <span className="font-mono text-xs">Private by default. Public when you want.</span>
          </div>
        </footer>
      </div>
    </>
  )
}
