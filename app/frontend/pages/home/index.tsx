import { Head, Link, usePage } from '@inertiajs/react'
import AppShell from '../../components/app_shell'
import Cta, { EmptyState, type CallToAction } from '../../components/team/cta'
import Filters, { ViewToggle, type HomeFilters, type PersonOption } from '../../components/team/filters'
import Hero, { type HeroData } from '../../components/team/hero'
import LaunchRow from '../../components/team/launch_row'
import OverallTopTen, { type Overall } from '../../components/team/overall_top_ten'
import { NewInToolbox, PersonTable, type PersonData } from '../../components/team/person_view'
import { SearchField, SearchResults, useSearch, type SearchData } from '../../components/team/search_results'
import WhatWeUseTable, { type WhatWeUseRow } from '../../components/team/what_we_use_table'
import type { Launch, SharedProps } from '../../types'

type Props = {
  filters: HomeFilters
  people: PersonOption[]
  notice: string | null
  /** The viewer is counted here but shares with nobody, so these numbers include picks colleagues cannot see. */
  private_picks: boolean
  empty_reason: string | null
  launches: Launch[]
  hero: HeroData | null
  rows: WhatWeUseRow[]
  overall: Overall
  person: PersonData | null
  cta: CallToAction | null
  all_vibe_checks_url: string
  search?: SearchData
}

const sectionHeader = 'flex flex-wrap items-end justify-between gap-x-6 gap-y-4 border-b border-line-strong pb-4'
const sectionTitle = 'font-serif text-[32px] leading-[1.1] tracking-[-0.02em] text-fg md:text-[40px]'
const note = 'mt-4 max-w-[660px] text-caption text-fg-soft'

export default function Home({
  filters,
  people,
  notice,
  private_picks,
  empty_reason,
  launches,
  hero,
  rows,
  overall,
  person,
  cta,
  all_vibe_checks_url,
  search,
}: Props) {
  const { current_user } = usePage<SharedProps>().props
  const { query, setQuery, failed, inputRef } = useSearch(filters)
  const empty = empty_reason !== null
  const subject = person?.person

  return (
    <AppShell search={<SearchField value={query} onChange={setQuery} inputRef={inputRef} />}>
      <Head title={subject ? `The AI tools ${subject.name} uses` : 'The AI tools Every uses'} />

      <SearchResults query={query} search={search} failed={failed} show={filters.show} />

      <section className="flex flex-col gap-10 lg:flex-row lg:items-end lg:justify-between">
        <div className="min-w-0">
          <h1 className="font-serif text-[44px] leading-[1.02] tracking-[-0.02em] text-fg md:text-[64px]">
            The AI tools <em className={subject ? 'italic' : 'italic text-sky'}>{subject ? subject.name : 'Every'}</em> uses
          </h1>
          <p className="mt-4 max-w-[660px] text-[19px] leading-[1.5] text-fg-soft">
            {person && subject ? (
              <>
                {subject.name} ranked {person.ranked_count} of {person.kinds.length} kinds of work. Where {subject.name}'s first pick is not the
                team's most used, a note says so.{' '}
                <Link href={`/${subject.handle}`} className="text-link">
                  See {subject.name}'s full page
                </Link>
              </>
            ) : (
              'Toolbox is where each of us ranks the tools and models we use for every kind of work. See what the team relies on, then add yours.'
            )}
          </p>
          <div className="mt-7">
            <Filters filters={filters} people={people} />
          </div>
          {notice && (
            <p role="status" className={note}>
              {notice}
            </p>
          )}
          {private_picks ? (
            <p className={note}>
              {subject && subject.handle === current_user?.handle
                ? 'Only you can see this page.'
                : 'These counts include your private picks. Only you can see them.'}
            </p>
          ) : (
            current_user?.visibility === 'link' &&
            !subject && <p className={note}>You share with anyone with the link, so you are listed here and in search.</p>
          )}
        </div>
        {person ? <NewInToolbox data={person} /> : hero && <div className="hidden w-full md:block lg:w-auto"><Hero hero={hero} /></div>}
      </section>

      {!person && launches.length > 0 && (
        <section aria-labelledby="launches" className="mt-16 md:mt-20">
          <div className={sectionHeader}>
            <h2 id="launches" className={sectionTitle}>
              Latest model launches
            </h2>
            <a href={all_vibe_checks_url} target="_blank" rel="noopener noreferrer" className="text-link text-sm text-fg-soft">
              All Vibe Checks <span aria-hidden="true">↗</span>
            </a>
          </div>
          <ul>
            {launches.map((launch) => (
              <LaunchRow key={launch.model.slug} launch={launch} />
            ))}
          </ul>
        </section>
      )}

      <section aria-labelledby="use" className="mt-16 md:mt-20">
        <div className={sectionHeader}>
          <h2 id="use" className={sectionTitle}>
            {subject ? `What ${subject.name} uses` : 'What we use'}
          </h2>
          {!person && !empty && <ViewToggle filters={filters} />}
        </div>
        <div className={empty ? 'mt-8' : 'mt-2'}>
          {empty ? (
            <EmptyState cta={cta} signedIn={Boolean(current_user)} />
          ) : person ? (
            <PersonTable data={person} show={filters.show} />
          ) : filters.overall ? (
            <div className="mt-8">
              <OverallTopTen overall={overall} />
            </div>
          ) : (
            <WhatWeUseTable rows={rows} show={filters.show} />
          )}
        </div>
      </section>

      {cta && !empty && (
        <div className="mt-16 md:mt-20">
          <Cta cta={cta} signedIn={Boolean(current_user)} />
        </div>
      )}
    </AppShell>
  )
}
