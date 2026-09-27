import { Head, Link, router, usePage } from '@inertiajs/react'
import { useState } from 'react'
import AppShell from '../../components/app_shell'
import { AddButton, people, RankRow } from '../../components/map_rank'
import ToolMark from '../../components/tool_mark'
import type { MapDiscovery, MapPanel, MapSummary, MapUpgrade, SharedProps } from '../../types'

type Props = {
  summary: MapSummary
  categories: MapPanel[]
  discovery: MapDiscovery
}

function Stat({ value, label }: { value: number; label: string }) {
  return (
    <div className="border-t border-rule pt-3">
      <p className="display text-4xl tabular-nums sm:text-5xl">{value}</p>
      <p className="eyebrow mt-1">{label}</p>
    </div>
  )
}

function SwitchButton({ upgrade }: { upgrade: MapUpgrade }) {
  const [state, setState] = useState<'idle' | 'saving' | 'done'>('idle')
  if (state === 'done') return <span className="text-xs text-ink-muted">Switched</span>

  const switchModel = () => {
    setState('saving')
    router.patch(
      '/loadout',
      {
        operations: [
          { op: 'remove', category: upgrade.category.slug, tool: upgrade.tool.slug, model: upgrade.from_model.slug },
          { op: 'add', category: upgrade.category.slug, tool: upgrade.tool.slug, model: upgrade.to_model.slug },
        ],
      },
      { preserveScroll: true, onSuccess: () => setState('done'), onError: () => setState('idle'), onCancel: () => setState('idle') },
    )
  }

  return (
    <button
      type="button"
      onClick={switchModel}
      disabled={state === 'saving'}
      className="inline-flex shrink-0 items-center rounded-full bg-ink px-3 py-1.5 text-xs font-medium text-paper transition hover:bg-ink-soft active:scale-95 disabled:opacity-50"
    >
      {state === 'saving' ? 'Switching' : 'Switch'}
    </button>
  )
}

const DISCOVERY_CARDS = 4

function Discovery({ discovery }: { discovery: MapDiscovery }) {
  const { upgrades } = discovery
  const claimed = discovery.empty_categories.filter((row) => row.tools.length > 0)
  const empty = claimed.slice(0, Math.max(DISCOVERY_CARDS - upgrades.length, 2))
  const rest = discovery.empty_categories.filter((row) => !empty.includes(row))
  if (empty.length === 0 && upgrades.length === 0 && rest.length === 0) return null

  return (
    <section aria-labelledby="discovery-heading" className="animate-rise mt-14 rounded-[1.75rem] bg-paper-deep p-5 sm:p-8">
      <div className="flex flex-wrap items-baseline justify-between gap-2">
        <h2 id="discovery-heading" className="display text-3xl sm:text-4xl">
          For you
        </h2>
        <p className="eyebrow text-every-blue">What colleagues know that your loadout doesn't</p>
      </div>

      <div className="mt-6 grid grid-cols-1 gap-4 lg:grid-cols-2">
        {upgrades.map((upgrade) => (
          <article key={`${upgrade.category.slug}-${upgrade.tool.slug}-${upgrade.to_model.slug}`} className="card flex flex-col gap-4 p-5">
            <p className="eyebrow">Moving on · {upgrade.category.name}</p>
            <p className="font-serif text-xl leading-snug sm:text-2xl">
              {upgrade.colleagues_count} {upgrade.colleagues_count === 1 ? 'colleague' : 'colleagues'} moved to{' '}
              <span className="text-every-blue">{upgrade.to_model.name}</span>
            </p>
            <p className="text-sm leading-relaxed text-ink-soft">
              You still use {upgrade.from_model.name} in {upgrade.tool.name}. Switching keeps {upgrade.tool.name} and swaps the
              model on your loadout.
            </p>
            <div className="mt-auto flex items-center justify-between gap-3 border-t border-rule/70 pt-4">
              <div className="flex min-w-0 items-center gap-2.5 text-sm">
                <ToolMark item={upgrade.tool} size="sm" />
                <span className="min-w-0 truncate">
                  <span className="text-ink-muted line-through decoration-ink-muted/40">{upgrade.from_model.name}</span>
                  <span aria-hidden="true" className="px-1.5 text-ink-muted">
                    →
                  </span>
                  <span className="font-medium">{upgrade.to_model.name}</span>
                </span>
              </div>
              <SwitchButton upgrade={upgrade} />
            </div>
          </article>
        ))}

        {empty.map(({ category, people_count, tools }) => (
          <article key={category.slug} className="card flex flex-col gap-4 p-5">
            <div className="flex items-baseline justify-between gap-3">
              <p className="eyebrow">Unexplored · {category.name}</p>
              <Link href={`/map/${category.slug}`} className="text-xs text-ink-muted underline decoration-rule underline-offset-4 hover:text-ink">
                See all
              </Link>
            </div>
            <p className="font-serif text-xl leading-snug sm:text-2xl">
              Nothing for {category.name.toLowerCase()} yet. Here's what {people_count === 1 ? 'one colleague uses' : `${people_count} colleagues use`}.
            </p>
            <ul className="flex flex-col divide-y divide-rule/70">
              {tools.map((rank) => (
                <li key={rank.item.slug} className="flex items-center gap-3 py-2.5 first:pt-0 last:pb-0">
                  <ToolMark item={rank.item} size="sm" />
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-medium">{rank.item.name}</p>
                    <p className="truncate text-xs text-ink-muted">
                      {people(rank.count)}
                      {rank.usual_model && ` · with ${rank.usual_model.name}`}
                    </p>
                  </div>
                  <AddButton category={category.slug} tool={rank.item} model={rank.usual_model} inLoadout={rank.in_loadout} />
                </li>
              ))}
            </ul>
          </article>
        ))}
      </div>

      {rest.length > 0 && (
        <p className="mt-5 text-sm leading-relaxed text-ink-muted">
          Also not on your loadout:{' '}
          {rest.map((row, index) => (
            <span key={row.category.slug}>
              <Link href={`/map/${row.category.slug}`} className="text-ink underline decoration-rule underline-offset-4 hover:text-every-blue">
                {row.category.name}
              </Link>
              {index < rest.length - 1 ? ', ' : '.'}
            </span>
          ))}
        </p>
      )}
    </section>
  )
}

function CategoryPanel({ panel, index }: { panel: MapPanel; index: number }) {
  const slug = panel.category.slug
  const moreTools = panel.tools_count - panel.tools.length

  return (
    <article
      className="animate-rise flex flex-col border-t border-ink pt-5"
      style={{ animationDelay: `${Math.min(index, 6) * 60}ms` }}
      aria-labelledby={`panel-${slug}`}
    >
      <header className="flex items-start justify-between gap-4">
        <div className="min-w-0">
          <p className="eyebrow">
            {String(index + 1).padStart(2, '0')} · {people(panel.people_count)}
          </p>
          <h2 id={`panel-${slug}`} className="display mt-2 text-3xl sm:text-[2.35rem]">
            <Link href={`/map/${slug}`} className="hover:text-every-blue">
              {panel.category.name}
            </Link>
          </h2>
          {panel.category.blurb && <p className="mt-1.5 text-sm text-ink-muted">{panel.category.blurb}</p>}
        </div>
      </header>

      {panel.tools.length === 0 ? (
        <p className="mt-6 rounded-2xl border border-dashed border-rule px-5 py-8 text-center text-sm text-ink-muted">
          No one at Every has claimed this yet.
        </p>
      ) : (
        <>
          <p className="eyebrow mt-6 mb-3">Tools</p>
          <ol className="divide-y divide-rule/70">
            {panel.tools.map((rank, position) => (
              <RankRow key={rank.item.slug} rank={rank} position={position + 1} category={slug} />
            ))}
          </ol>
        </>
      )}

      {panel.models.length > 0 && (
        <>
          <p className="eyebrow mt-6 mb-3">Models</p>
          <ol className="divide-y divide-rule/70 rounded-2xl bg-paper-deep/60 px-4 py-3">
            {panel.models.map((rank, position) => (
              <RankRow
                key={rank.item.slug}
                rank={rank}
                position={position + 1}
                category={slug}
                size="sm"
                showPeople={false}
                addable={false}
              />
            ))}
          </ol>
        </>
      )}

      {(moreTools > 0 || panel.tools.length > 0) && (
        <Link
          href={`/map/${slug}`}
          className="mt-5 inline-flex items-center gap-1.5 self-start text-sm font-medium text-ink hover:text-every-blue"
        >
          {moreTools > 0 ? `All ${panel.tools_count} tools and who uses them` : 'Who uses what'}
          <span aria-hidden="true">→</span>
        </Link>
      )}
    </article>
  )
}

export default function MapIndex({ summary, categories, discovery }: Props) {
  const { current_user } = usePage<SharedProps>().props

  return (
    <AppShell wide>
      <Head title="The Every map" />

      <header className="animate-rise grid gap-10 lg:grid-cols-[1.4fr_1fr] lg:items-end">
        <div>
          <p className="eyebrow">The Every map · live</p>
          <h1 className="display mt-4 text-5xl sm:text-7xl">
            What Every <em className="text-every-blue">actually</em> uses.
          </h1>
          <p className="mt-5 max-w-xl text-lg leading-relaxed text-ink-soft">
            Every tool and model on this page comes from a colleague's loadout. Everyone counts; only public profiles are
            named.
          </p>
        </div>
        <div className="grid grid-cols-2 gap-x-6 gap-y-6">
          <Stat value={summary.members} label={summary.members === 1 ? 'Member' : 'Members'} />
          <Stat value={summary.picks} label="Picks" />
          <Stat value={summary.tools} label="Tools" />
          <Stat value={summary.categories} label="Kinds of work" />
        </div>
      </header>

      {current_user && <Discovery discovery={discovery} />}

      <div className="mt-16 grid grid-cols-1 gap-x-12 gap-y-14 md:grid-cols-2">
        {categories.map((panel, index) => (
          <CategoryPanel key={panel.category.slug} panel={panel} index={index} />
        ))}
      </div>
    </AppShell>
  )
}
