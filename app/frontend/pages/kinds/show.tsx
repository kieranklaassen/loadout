import { Head, Link } from '@inertiajs/react'
import type { ReactNode } from 'react'
import AppShell from '../../components/app_shell'
import { ButtonLink } from '../../components/button'
import Count from '../../components/count'
import History from '../../components/kind/history'
import RankedList, { type Listing } from '../../components/kind/ranked_list'
import Setups, { type Setup } from '../../components/kind/setups'
import Takes, { type Take } from '../../components/kind/takes'
import { homeHref, kindHref, type Show } from '../../components/team/filters'
import type { CallToAction } from '../../components/team/cta'
import { relativeDate } from '../../lib/relative_date'
import type { Category, Count as CountValue, Era } from '../../types'

type Props = {
  filters: { show: Show }
  notice: string | null
  category: Category
  /** K of M: the people who ranked this kind, out of everyone counted. */
  ranked: CountValue
  tools: Listing[]
  models: Listing[]
  setups: Setup[]
  takes: Take[]
  last_update_at: string | null
  /** The team's number one over time; null unless there are two or more eras. */
  eras: Era[] | null
  cta: CallToAction
}

const SHOWS: { value: Show; label: string }[] = [
  { value: 'team', label: 'Every team' },
  { value: 'others', label: 'Everyone else' },
]

const sectionTitle = 'font-serif text-[32px] leading-[1.1] tracking-[-0.02em] text-fg md:text-[36px]'

function Section({ id, title, aside, children }: { id: string; title: string; aside?: ReactNode; children: ReactNode }) {
  return (
    <section aria-labelledby={id} className="mt-16 md:mt-[72px]">
      <div className="flex flex-wrap items-end justify-between gap-x-6 gap-y-3 border-b border-line-strong pb-3.5">
        <h2 id={id} className={sectionTitle}>
          {title}
        </h2>
        {aside}
      </div>
      {children}
    </section>
  )
}

/** What the square and round tiles mean, as in the mock. */
function Legend() {
  return (
    <p className="flex flex-wrap items-center gap-x-[18px] gap-y-1 text-caption text-fg-muted">
      <span className="inline-flex items-center gap-2">
        <span aria-hidden="true" className="size-[18px] rounded-soft bg-fg" />
        Tool: the app you use
      </span>
      <span className="inline-flex items-center gap-2">
        <span aria-hidden="true" className="size-[18px] rounded-full bg-fg" />
        Model: the AI behind it
      </span>
    </p>
  )
}

/** Every team / Everyone else: the same two groups as Home's SHOW, kept on this kind. */
function ShowToggle({ slug, show }: { slug: string; show: Show }) {
  const link = 'inline-flex min-h-11 items-center px-4 py-2 text-sm md:min-h-0'

  return (
    <nav aria-label="Show" className="mt-5 flex">
      {SHOWS.map(({ value, label }) => (
        <Link
          key={value}
          href={kindHref(slug, value)}
          preserveScroll
          preserveState
          aria-current={value === show ? 'page' : undefined}
          className={`${link} ${value === show ? 'bg-sky font-semibold text-on-light' : 'text-fg-soft ring-1 ring-inset ring-line hover:text-fg'}`}
        >
          {label}
        </Link>
      ))}
    </nav>
  )
}

export default function KindPage({ filters, notice, category, ranked, tools, models, setups, takes, last_update_at, eras, cta }: Props) {
  const { show } = filters
  const empty = ranked.n === 0
  const name = category.name.toLowerCase()

  return (
    <AppShell>
      <Head title={`${category.name} on Toolbox`} />

      <Link href={homeHref({ show })} className="text-link text-sm text-fg-muted">
        <span aria-hidden="true">←</span> The AI tools Every uses
      </Link>

      <div className="mt-3.5 flex flex-col gap-6 md:flex-row md:items-end md:justify-between">
        <div className="min-w-0">
          <h1 className="font-serif text-[48px] leading-[1.02] tracking-[-0.02em] text-fg md:text-[72px]">{category.name}</h1>
          <p className="mt-2.5 max-w-[660px] text-lg text-fg-soft">
            {category.blurb}
            {!empty && (
              <>
                {' '}
                <Count count={ranked} label="ranked it" />
                {last_update_at && `, most recently ${relativeDate(last_update_at)}`}.
              </>
            )}
          </p>
          <ShowToggle slug={category.slug} show={show} />
          {notice && (
            <p role="status" className="mt-4 max-w-[660px] text-caption text-fg-soft">
              {notice}
            </p>
          )}
        </div>
        <ButtonLink href={cta.href} size="lg" className="self-start whitespace-nowrap md:shrink-0 md:self-auto">
          {cta.label}
        </ButtonLink>
      </div>

      {empty ? (
        <section aria-label="Nothing ranked yet" className="panel mt-16 px-6 py-10 md:mt-[72px] md:px-14 md:py-14">
          <h2 className="font-serif text-[32px] leading-[1.08] tracking-[-0.02em] text-fg md:text-[40px]">Nobody has ranked {name} yet</h2>
          <p className="mt-4 max-w-[560px] text-lg leading-[1.55] text-fg-soft">When someone shares their {name} picks, this page fills in.</p>
        </section>
      ) : (
        <>
          <Section id="use" title="What we use" aside={<Legend />}>
            <div className="mt-2 grid gap-x-14 lg:grid-cols-2">
              <RankedList title="Tools" listings={tools} empty="No tools ranked yet" />
              <RankedList title="Models" listings={models} empty="Nobody has picked a model yet" />
            </div>
            {setups.length > 0 && <Setups setups={setups} />}
          </Section>

          {takes.length > 0 && (
            <Section id="takes" title="Takes on these models">
              <p className="mt-4 max-w-[660px] text-caption text-fg-soft">Every's Vibe Checks of the models people ranked here.</p>
              <Takes takes={takes} />
            </Section>
          )}

          {eras && (
            <Section id="history" title="What we used before">
              <p className="mt-4 max-w-[660px] text-caption text-fg-soft">
                The team's number-one tool and model over time. It reflects who was sharing at the time as well as who switched.
              </p>
              <div className="mt-5">
                <History eras={eras} />
              </div>
            </Section>
          )}
        </>
      )}
    </AppShell>
  )
}
