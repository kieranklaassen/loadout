import { Head, Link } from '@inertiajs/react'
import AppShell from '../../components/app_shell'
import Avatar from '../../components/avatar'
import { people, RankRow } from '../../components/map_rank'
import ToolMark from '../../components/tool_mark'
import type { Category, MapPanel, MapPerson } from '../../types'

type Props = {
  panel: MapPanel
  people: MapPerson[]
  categories: Category[]
}

function CategoryTabs({ categories, current }: { categories: Category[]; current: string }) {
  return (
    <nav aria-label="Categories" className="-mx-5 overflow-x-auto px-5 sm:mx-0 sm:px-0">
      <ul className="flex w-max gap-1.5">
        {categories.map((category) => {
          const active = category.slug === current
          return (
            <li key={category.slug}>
              <Link
                href={`/map/${category.slug}`}
                aria-current={active ? 'page' : undefined}
                className={`block whitespace-nowrap rounded-full px-3.5 py-1.5 text-sm transition ${active ? 'bg-ink text-paper' : 'text-ink-soft ring-1 ring-rule hover:bg-white hover:text-ink'}`}
              >
                {category.name}
              </Link>
            </li>
          )
        })}
      </ul>
    </nav>
  )
}

function PersonCard({ person }: { person: MapPerson }) {
  return (
    <li>
      <Link href={`/${person.handle}`} className="card group flex h-full items-start gap-4 p-4 transition hover:shadow-lift">
        <Avatar name={person.name} src={person.avatar_url} />
        <div className="min-w-0 flex-1">
          <p className="truncate font-medium group-hover:text-every-blue">{person.name}</p>
          <p className="font-mono text-xs text-ink-muted">loadout.every.to/{person.handle}</p>
          <ul className="mt-3 flex flex-col gap-1.5">
            {person.picks.map((pick) => (
              <li key={`${pick.tool.slug}-${pick.model?.slug ?? 'none'}`} className="flex min-w-0 items-center gap-2 text-sm">
                <ToolMark item={pick.tool} size="xs" />
                <span className="truncate">
                  {pick.tool.name}
                  {pick.model && <span className="text-ink-muted"> · {pick.model.name}</span>}
                </span>
                {pick.primary && person.picks.length > 1 && <span className="eyebrow shrink-0 !text-[0.6rem] text-every-blue">Go-to</span>}
              </li>
            ))}
          </ul>
        </div>
      </Link>
    </li>
  )
}

export default function MapShow({ panel, people: named, categories }: Props) {
  const { category } = panel
  const privateCount = Math.max(panel.people_count - named.length, 0)

  return (
    <AppShell wide>
      <Head title={`${category.name} · The Every map`} />

      <Link href="/map" className="eyebrow inline-flex items-center gap-1.5 hover:text-ink">
        <span aria-hidden="true">←</span> The Every map
      </Link>

      <header className="animate-rise mt-6 flex flex-col gap-6 border-b border-rule pb-8 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h1 className="display text-5xl sm:text-7xl">{category.name}</h1>
          {category.blurb && <p className="mt-3 max-w-xl text-lg text-ink-soft">{category.blurb}</p>}
        </div>
        <div className="flex gap-8 sm:text-right">
          <div>
            <p className="display text-4xl tabular-nums">{panel.people_count}</p>
            <p className="eyebrow mt-1">{panel.people_count === 1 ? 'Person' : 'People'}</p>
          </div>
          <div>
            <p className="display text-4xl tabular-nums">{panel.tools_count}</p>
            <p className="eyebrow mt-1">Tools</p>
          </div>
          <div>
            <p className="display text-4xl tabular-nums">{panel.models_count}</p>
            <p className="eyebrow mt-1">Models</p>
          </div>
        </div>
      </header>

      <div className="mt-6">
        <CategoryTabs categories={categories} current={category.slug} />
      </div>

      {panel.people_count === 0 ? (
        <div className="mt-14 rounded-[1.75rem] border border-dashed border-rule px-6 py-16 text-center">
          <p className="display text-3xl">Nobody at Every has claimed {category.name.toLowerCase()} yet.</p>
          <p className="mt-3 text-ink-muted">Add yours from your loadout and you'll be first on this page.</p>
        </div>
      ) : (
        <>
          <div className="mt-12 grid grid-cols-1 gap-12 lg:grid-cols-[1.5fr_1fr]">
            <section aria-labelledby="tools-heading" className="animate-rise">
              <h2 id="tools-heading" className="eyebrow mb-4 border-t border-ink pt-4">
                Tools, by people
              </h2>
              <ol className="divide-y divide-rule/70">
                {panel.tools.map((rank, position) => (
                  <RankRow key={rank.item.slug} rank={rank} position={position + 1} category={category.slug} />
                ))}
              </ol>
            </section>

            <section aria-labelledby="models-heading" className="animate-rise [animation-delay:80ms]">
              <h2 id="models-heading" className="eyebrow mb-4 border-t border-ink pt-4">
                Models, by people
              </h2>
              {panel.models.length === 0 ? (
                <p className="text-sm text-ink-muted">Nobody has named a model here yet.</p>
              ) : (
                <ol className="divide-y divide-rule/70">
                  {panel.models.map((rank, position) => (
                    <RankRow
                      key={rank.item.slug}
                      rank={rank}
                      position={position + 1}
                      category={category.slug}
                      size="sm"
                      addable={false}
                    />
                  ))}
                </ol>
              )}
            </section>
          </div>

          <section aria-labelledby="people-heading" className="mt-16">
            <div className="flex flex-wrap items-baseline justify-between gap-2 border-t border-ink pt-4">
              <h2 id="people-heading" className="display text-3xl">
                Who uses what
              </h2>
              <p className="text-sm text-ink-muted">
                {named.length} public {named.length === 1 ? 'profile' : 'profiles'}
                {privateCount > 0 && `, and ${people(privateCount)} who ${privateCount === 1 ? 'keeps' : 'keep'} theirs private`}
              </p>
            </div>
            {named.length === 0 ? (
              <p className="mt-6 text-ink-muted">Everyone here keeps their loadout private. Their picks still count above.</p>
            ) : (
              <ul className="mt-6 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
                {named.map((person) => (
                  <PersonCard key={person.handle} person={person} />
                ))}
              </ul>
            )}
          </section>
        </>
      )}
    </AppShell>
  )
}
