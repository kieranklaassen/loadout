import { Head, Link } from '@inertiajs/react'
import AppShell from '../../components/app_shell'
import Avatar from '../../components/avatar'
import { ButtonLink, buttonClasses } from '../../components/button'
import ShareBar from '../../components/share_bar'
import ToolMark from '../../components/tool_mark'
import { LoadoutGlyph } from '../../components/wordmark'
import { fullDate, relativeDate } from '../../lib/relative_date'
import type { CatalogItem, ChangeEvent, Entry, LoadoutCategory, ProfileDetail } from '../../types'

type Props = {
  profile: ProfileDetail
  categories: LoadoutCategory[]
  recent_changes: ChangeEvent[]
  is_owner: boolean
}

export function changeSource(change: Pick<ChangeEvent, 'source' | 'client_name'>): string {
  if (change.client_name) return `via ${change.client_name}`
  switch (change.source) {
    case 'web':
      return 'on the web'
    case 'mcp':
      return 'via an agent'
    case 'webmcp':
      return 'via a browser agent'
    default: {
      const unknown: never = change.source
      return unknown
    }
  }
}

function EveryBadge() {
  return (
    <span
      title="Every member"
      className="inline-flex items-center gap-1.5 rounded-full border border-every-blue/40 px-2.5 py-0.5 font-mono text-[0.68rem] font-medium uppercase tracking-[0.12em] text-every-blue"
    >
      <span className="h-1.5 w-1.5 rounded-full bg-every-blue" aria-hidden="true" />
      Every
    </span>
  )
}

function ModelChip({ model }: { model: CatalogItem }) {
  return (
    <span className="inline-flex items-center gap-1.5 rounded-full border border-rule bg-white py-1 pl-1 pr-3 text-sm text-ink-soft">
      <ToolMark item={model} size="xs" className="rounded-full" />
      {model.name}
    </span>
  )
}

function PrivateBanner() {
  return (
    <div className="mb-10 flex flex-col gap-3 rounded-2xl border border-dashed border-ink/20 bg-paper-deep/70 px-5 py-4 sm:flex-row sm:items-center sm:justify-between">
      <p className="flex items-start gap-3 text-sm text-ink-soft">
        <svg viewBox="0 0 20 20" className="mt-0.5 h-4 w-4 shrink-0 text-ink" aria-hidden="true" fill="none" stroke="currentColor" strokeWidth="1.6">
          <rect x="4" y="9" width="12" height="8" rx="2" />
          <path d="M7 9V6.5a3 3 0 0 1 6 0V9" />
        </svg>
        <span>
          <strong className="font-medium text-ink">Only you can see this.</strong> Your profile is private: everyone else gets a
          “not found”.
        </span>
      </p>
      <Link href="/settings" className="shrink-0 text-sm font-medium text-every-blue underline-offset-4 hover:underline">
        Make it public
      </Link>
    </div>
  )
}

function GoToPick({ entry }: { entry: Entry }) {
  return (
    <div className="flex flex-col gap-5">
      <div className="flex items-center gap-4">
        <ToolMark item={entry.tool} size="lg" />
        <div className="min-w-0">
          <p className="eyebrow !text-[0.65rem] text-every-blue">Go-to</p>
          <h3 className="mt-0.5 truncate text-2xl font-semibold tracking-tight sm:text-[1.75rem]">{entry.tool.name}</h3>
        </div>
      </div>
      {entry.model && (
        <div>
          <ModelChip model={entry.model} />
        </div>
      )}
      {entry.note && (
        <blockquote className="border-l-2 border-ink pl-4 font-serif text-xl italic leading-snug text-ink-soft sm:text-[1.4rem]">
          “{entry.note}”
        </blockquote>
      )}
    </div>
  )
}

function OtherPick({ entry }: { entry: Entry }) {
  return (
    <li className="flex items-start gap-3 py-3">
      <ToolMark item={entry.tool} size="sm" className="mt-0.5" />
      <div className="min-w-0">
        <p className="text-[0.95rem]">
          <span className="font-medium">{entry.tool.name}</span>
          {entry.model && <span className="text-ink-muted"> with {entry.model.name}</span>}
        </p>
        {entry.note && <p className="mt-0.5 text-sm text-ink-muted">{entry.note}</p>}
      </div>
    </li>
  )
}

function CategorySection({ category, index }: { category: LoadoutCategory; index: number }) {
  const [goTo, ...rest] = category.entries
  return (
    <section
      aria-labelledby={`category-${category.slug}`}
      className="animate-rise grid gap-6 border-t border-rule py-9 sm:grid-cols-[11rem_1fr] sm:gap-10"
      style={{ animationDelay: `${Math.min(index, 6) * 60}ms` }}
    >
      <header>
        <h2 id={`category-${category.slug}`} className="eyebrow !text-ink">
          {category.name}
        </h2>
        {category.blurb && <p className="mt-2 hidden text-sm leading-relaxed text-ink-muted sm:block">{category.blurb}</p>}
      </header>
      <div>
        {goTo && <GoToPick entry={goTo} />}
        {rest.length > 0 && (
          <div className="mt-7">
            <p className="eyebrow !text-[0.65rem]">Also uses</p>
            <ul className="mt-1 divide-y divide-rule/80">
              {rest.map((entry) => (
                <OtherPick key={entry.id} entry={entry} />
              ))}
            </ul>
          </div>
        )}
      </div>
    </section>
  )
}

function RecentChanges({ changes }: { changes: ChangeEvent[] }) {
  return (
    <section aria-labelledby="recent-changes" className="lg:sticky lg:top-24">
      <h2 id="recent-changes" className="eyebrow !text-ink">
        Recent changes
      </h2>
      <ol className="relative mt-5 space-y-6 border-l border-rule pl-5">
        {changes.map((change) => (
          <li key={`${change.id}-${change.action}`} className="relative">
            <span
              aria-hidden="true"
              className={`absolute -left-[1.6rem] top-1.5 h-2.5 w-2.5 rounded-full ring-4 ring-paper ${change.action === 'switched' ? 'bg-every-blue' : 'bg-ink/25'}`}
            />
            <p className="text-[0.95rem] leading-snug text-ink">{change.sentence}</p>
            <p className="mt-1 font-mono text-[0.7rem] uppercase tracking-[0.06em] text-ink-muted">
              <time dateTime={change.created_at} title={fullDate(change.created_at)}>
                {relativeDate(change.created_at)}
              </time>{' '}
              · {changeSource(change)}
            </p>
          </li>
        ))}
      </ol>
    </section>
  )
}

function EmptyLoadout({ isOwner, name }: { isOwner: boolean; name: string }) {
  if (!isOwner) {
    return (
      <div className="border-t border-rule py-16 text-center">
        <p className="display text-3xl text-ink-muted">Nothing here yet.</p>
        <p className="mt-3 text-ink-muted">{name} hasn’t picked their tools.</p>
      </div>
    )
  }
  return (
    <div className="card flex flex-col items-start gap-5 p-8 sm:p-10">
      <div className="flex -space-x-2" aria-hidden="true">
        {[220, 18, 345].map((hue, i) => (
          <ToolMark key={hue} item={{ hue, monogram: ['Cu', 'Cl', 'Rw'][i], name: '' }} size="md" className="ring-4 ring-white" />
        ))}
      </div>
      <div>
        <h2 className="display text-3xl sm:text-4xl">Your loadout is empty.</h2>
        <p className="mt-3 max-w-md text-ink-soft">
          Tap the tools and models you use for coding, writing, research and more. It takes about a minute, and you can skip any
          category.
        </p>
      </div>
      <ButtonLink href="/loadout/edit" size="lg">
        Pick your tools
      </ButtonLink>
    </div>
  )
}

function MakeYourOwn() {
  return (
    <aside className="relative mt-20 overflow-hidden rounded-[1.75rem] bg-ink px-7 py-10 text-paper sm:px-12 sm:py-14">
      <div className="relative z-10 max-w-lg">
        <p className="font-mono text-[0.72rem] uppercase tracking-[0.08em] text-paper/60">Loadout, from Every</p>
        <h2 className="display mt-3 text-4xl sm:text-5xl">What’s in your AI loadout?</h2>
        <p className="mt-4 text-paper/75">Claim your link, tap the tools you use per task, and share it. About a minute.</p>
        {/* A full page navigation: the OmniAuth middleware answers with a redirect to Every. */}
        <a href="/auth/every" className={`${buttonClasses('blue', 'lg')} mt-7`}>
          Make your own Loadout
        </a>
      </div>
      <LoadoutGlyph className="pointer-events-none absolute -bottom-10 -right-8 h-56 w-56 text-paper opacity-[0.07] sm:h-72 sm:w-72" />
    </aside>
  )
}

export default function ProfileShow({ profile, categories, recent_changes, is_owner }: Props) {
  const firstName = profile.name.split(/\s+/)[0]
  const shareText = is_owner ? 'My AI loadout: the tools and models I use, per task.' : `${profile.name}’s AI loadout`
  const hasPicks = categories.length > 0

  return (
    <AppShell wide>
      <Head title={`${profile.name}’s AI loadout`} />

      {is_owner && !profile.public && <PrivateBanner />}

      <header className="animate-rise flex flex-col gap-8 pb-12 sm:pb-16 lg:flex-row lg:items-end lg:justify-between">
        <div className="flex flex-col gap-6 sm:flex-row sm:items-end sm:gap-8">
          <Avatar name={profile.name} src={profile.avatar_url} size="xl" className="shadow-[var(--shadow-card)]" />
          <div className="min-w-0">
            <div className="flex flex-wrap items-center gap-3">
              <p className="eyebrow">AI loadout</p>
              {profile.every_member && <EveryBadge />}
            </div>
            <h1 className="display mt-3 break-words text-5xl sm:text-7xl">{profile.name}</h1>
            {profile.bio && <p className="mt-4 max-w-xl text-lg leading-relaxed text-ink-soft">{profile.bio}</p>}
            <p className="mt-4 font-mono text-sm text-ink-muted">{profile.display_url}</p>
          </div>
        </div>

        <div className="flex flex-col gap-3 lg:items-end">
          {profile.public && <ShareBar url={profile.url} text={shareText} />}
          {is_owner && (
            <Link href="/loadout/edit" className="text-sm font-medium text-ink-soft underline decoration-rule underline-offset-4 hover:text-ink">
              Edit your loadout
            </Link>
          )}
        </div>
      </header>

      {hasPicks ? (
        <div className="grid gap-14 lg:grid-cols-[1fr_20rem] lg:gap-16">
          <div>
            {categories.map((category, index) => (
              <CategorySection key={category.slug} category={category} index={index} />
            ))}
          </div>
          {recent_changes.length > 0 && (
            <div className="border-t border-rule pt-9">
              <RecentChanges changes={recent_changes} />
            </div>
          )}
        </div>
      ) : (
        <EmptyLoadout isOwner={is_owner} name={firstName} />
      )}

      {!is_owner && <MakeYourOwn />}
    </AppShell>
  )
}
