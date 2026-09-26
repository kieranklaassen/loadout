import { Link, router, usePage } from '@inertiajs/react'
import { useState } from 'react'
import type { CatalogItem, MapRank, ProfileSummary, SharedProps } from '../types'
import Avatar from './avatar'
import ToolMark from './tool_mark'

export function percent(share: number) {
  return `${Math.round(share * 100)}%`
}

export function people(count: number) {
  return `${count} ${count === 1 ? 'person' : 'people'}`
}

/** Named public profiles as a small overlapping row, then "and N others" for everyone else. */
export function PeopleStack({
  people: named,
  othersCount,
  max = 5,
}: {
  people: ProfileSummary[]
  othersCount: number
  max?: number
}) {
  const shown = named.slice(0, max)
  const others = othersCount + (named.length - shown.length)
  if (shown.length === 0 && others === 0) return null

  return (
    <div className="flex min-w-0 items-center gap-2">
      {shown.length > 0 && (
        <div className="flex -space-x-2">
          {shown.map((person) => (
            <Link
              key={person.handle}
              href={`/${person.handle}`}
              title={person.name}
              className="rounded-full ring-2 ring-white transition hover:z-10 hover:-translate-y-0.5"
            >
              <Avatar name={person.name} src={person.avatar_url} size="sm" />
              <span className="sr-only">{person.name}</span>
            </Link>
          ))}
        </div>
      )}
      <span className="truncate text-xs text-ink-muted">
        {shown.length === 0
          ? `${people(others)}, all private`
          : others > 0
            ? `and ${others} ${others === 1 ? 'other' : 'others'}`
            : null}
      </span>
    </div>
  )
}

/** One-click add to the viewer's loadout. Hidden when nobody is signed in. */
export function AddButton({
  category,
  tool,
  model,
  inLoadout,
  label = 'Add',
}: {
  category: string
  tool: CatalogItem
  model?: CatalogItem | null
  inLoadout: boolean
  label?: string
}) {
  const { current_user } = usePage<SharedProps>().props
  const [state, setState] = useState<'idle' | 'saving' | 'added'>('idle')
  if (!current_user) return null

  if (inLoadout || state === 'added') {
    return (
      <span className="inline-flex shrink-0 items-center gap-1 rounded-full px-2.5 py-1 text-xs text-ink-muted">
        <svg viewBox="0 0 16 16" className="h-3.5 w-3.5 text-every-blue" aria-hidden="true">
          <path d="M3.5 8.5l3 3 6-7" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
        Yours
      </span>
    )
  }

  const add = () => {
    setState('saving')
    router.patch(
      '/loadout',
      { operations: [{ op: 'add', category, tool: tool.slug, model: model?.slug ?? null }] },
      {
        preserveScroll: true,
        onSuccess: () => setState('added'),
        onError: () => setState('idle'),
        onCancel: () => setState('idle'),
      },
    )
  }

  const name = model ? `${tool.name} with ${model.name}` : tool.name

  return (
    <button
      type="button"
      onClick={add}
      disabled={state === 'saving'}
      aria-label={`${label} ${name} to your loadout`}
      className="inline-flex shrink-0 items-center gap-1 rounded-full bg-white px-2.5 py-1 text-xs font-medium text-ink ring-1 ring-rule transition hover:ring-every-blue/50 hover:text-every-blue active:scale-95 disabled:opacity-50"
    >
      <span aria-hidden="true" className="text-sm leading-none">
        +
      </span>
      {state === 'saving' ? 'Adding' : label}
    </button>
  )
}

/**
 * A ranked horizontal share bar: position, tile, name, people count, and a bar
 * scaled to the share of the category's people.
 */
export function RankRow({
  rank,
  position,
  category,
  size = 'md',
  showPeople = true,
  addable = true,
}: {
  rank: MapRank
  position: number
  category: string
  size?: 'sm' | 'md'
  showPeople?: boolean
  addable?: boolean
}) {
  const lead = position === 1
  const width = `${Math.max(rank.share * 100, 3)}%`

  return (
    <li className="group py-3 first:pt-0 last:pb-0">
      <div className="flex items-center gap-3">
        <span className="w-5 shrink-0 font-mono text-[0.7rem] tabular-nums text-ink-muted">
          {String(position).padStart(2, '0')}
        </span>
        <ToolMark item={rank.item} size={size === 'sm' ? 'xs' : 'sm'} />
        <div className="min-w-0 flex-1">
          <div className="flex items-baseline justify-between gap-3">
            <p className={`truncate ${size === 'sm' ? 'text-sm' : 'text-[0.95rem] font-medium'} text-ink`}>
              {rank.item.name}
              {rank.usual_model && size === 'md' && (
                <span className="font-normal text-ink-muted"> · mostly {rank.usual_model.name}</span>
              )}
            </p>
            <p className="shrink-0 font-mono text-xs tabular-nums text-ink-soft">
              {rank.count}
              <span className="text-ink-muted"> · {percent(rank.share)}</span>
            </p>
          </div>
          <div className="mt-1.5 h-1.5 overflow-hidden rounded-full bg-ink/[0.06]">
            <div
              className={`h-full rounded-full transition-[width] duration-700 ease-out ${lead ? 'bg-every-blue' : 'bg-ink/70'}`}
              style={{ width }}
            />
          </div>
        </div>
      </div>
      {(showPeople || addable) && (
        <div className="mt-2 flex min-h-7 items-center justify-between gap-3 pl-8 sm:pl-[4.25rem]">
          {showPeople ? <PeopleStack people={rank.people} othersCount={rank.others_count} /> : <span />}
          {addable && <AddButton category={category} tool={rank.item} model={rank.usual_model} inLoadout={rank.in_loadout} />}
        </div>
      )}
    </li>
  )
}
