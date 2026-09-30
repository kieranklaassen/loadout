import { Link } from '@inertiajs/react'
import { rankLabel } from '../../lib/rank_label'
import type { Count as CountValue, MarkItem } from '../../types'
import Count from '../count'
import Mark from '../mark'
import { sectionLabelClasses } from '../section_label'

export type Person = { handle: string; name: string }

/**
 * A tool or model, N of M, and the people who ranked it 1st, 2nd and 3rd. The server names only people the
 * viewer may open; `unnamed` is how many other people counted have it, never split by rank.
 */
export type Listing = { item: MarkItem; count: CountValue; by_rank: Record<string, Person[]>; unnamed: number }

/** "and 2 others" after names, "2 people" without any. */
export function othersText(unnamed: number, named: boolean) {
  if (unnamed <= 0) return ''
  const people = unnamed === 1 ? 'other' : 'others'
  return named ? `and ${unnamed} ${people}` : `${unnamed} ${unnamed === 1 ? 'person' : 'people'}, not listed`
}

/** "1st for Kieran, Dan; 2nd for Rob · and 2 others". */
function RankNames({ byRank, unnamed }: { byRank: Listing['by_rank']; unnamed: number }) {
  const groups = Object.entries(byRank).filter(([, people]) => people.length > 0)
  const others = othersText(unnamed, groups.length > 0)

  return (
    <p className="mt-0.5 text-sm text-fg-muted">
      {groups.map(([rank, people], index) => (
        <span key={rank}>
          {index > 0 && '; '}
          {rankLabel(Number(rank))} for{' '}
          {people.map((person, position) => (
            <span key={person.handle}>
              {position > 0 && ', '}
              <Link href={`/${person.handle}`} className="text-fg-soft underline decoration-line-quiet underline-offset-4 hover:text-fg">
                {person.name}
              </Link>
            </span>
          ))}
        </span>
      ))}
      {others && (groups.length > 0 ? ` · ${others}` : others)}
    </p>
  )
}

/** The tools (or the models) people ranked in a kind, most used first. */
export default function RankedList({ title, listings, empty }: { title: string; listings: Listing[]; empty: string }) {
  return (
    <section aria-label={title}>
      <h3 className={`${sectionLabelClasses} border-b border-line pb-1.5 pt-3.5`}>{title}</h3>
      {listings.length === 0 ? (
        <p className="border-b border-line py-4 text-fg-muted">{empty}</p>
      ) : (
        <ol>
          {listings.map(({ item, count, by_rank, unnamed }, index) => (
            <li
              key={item.slug}
              className="grid grid-cols-[1.5rem_2.75rem_minmax(0,1fr)] items-center gap-x-3.5 border-b border-line py-4 md:grid-cols-[1.5rem_2.75rem_minmax(0,1fr)_auto]"
            >
              <span className={`font-mono text-caption tabular-nums ${index === 0 ? 'text-yellow' : 'text-fg-muted'}`}>{index + 1}</span>
              <Mark item={item} size="lg" />
              <div>
                <p className="font-semibold text-fg">{item.name}</p>
                <RankNames byRank={by_rank} unnamed={unnamed} />
              </div>
              <Count count={count} label="use it" className="col-start-3 mt-1 text-sm text-fg-soft md:col-start-auto md:mt-0" />
            </li>
          ))}
        </ol>
      )}
    </section>
  )
}
