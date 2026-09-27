import { Link } from '@inertiajs/react'
import { staleness } from '../../lib/relative_date'
import type { Category, Count as CountValue } from '../../types'
import Count from '../count'
import Mark from '../mark'
import { sectionLabelClasses } from '../section_label'
import { kindHref, type Show } from './filters'
import type { Standing } from './overall_top_ten'

export type Leader = Standing & { runner_up: Standing | null }

export type WhatWeUseRow = {
  category: Category
  top_tool: Leader | null
  top_model: Leader | null
  ranked: CountValue
  last_update_at: string | null
  stale: boolean
}

function Top({ leader }: { leader: Leader }) {
  const { item, count, runner_up } = leader

  return (
    <>
      <div className="flex items-center gap-3">
        <Mark item={item} size="lg" />
        <div className="min-w-0">
          <p className="text-[17px] font-semibold leading-[1.2] text-fg">{item.name}</p>
          <p className="mt-0.5 text-caption text-fg-soft">
            <Count count={count} label="use it" />
          </p>
        </div>
      </div>
      {runner_up && (
        <p className="mt-2 flex items-center gap-1.5 text-caption">
          <Mark item={runner_up.item} size="xs" />
          <span className="text-fg-soft">{runner_up.item.name}</span>
          <span aria-hidden="true" className="text-fg-muted">
            {runner_up.count.n}
          </span>
          <Count count={runner_up.count} label="use it" className="sr-only" />
        </p>
      )}
    </>
  )
}

function Row({ row, show, now }: { row: WhatWeUseRow; show: Show; now?: Date }) {
  const { category, top_tool, top_model, stale, last_update_at } = row
  const cell = 'px-4 py-5 align-top'

  return (
    <tr className="border-b border-line">
      <th scope="row" className="w-[250px] py-5 pr-4 text-left align-top font-normal">
        <Link href={kindHref(category.slug, show)} className="block font-serif text-[22px] leading-[1.1] text-fg hover:underline">
          {category.name}
        </Link>
        <span className="mt-[3px] block text-caption text-fg-muted">{category.blurb}</span>
        {stale && last_update_at && <span className="mt-1 block text-caption text-coral">{staleness(last_update_at, now)}</span>}
      </th>
      {top_tool ? (
        <>
          <td data-label="Most used tool" className={`${cell} w-[380px]`}>
            <Top leader={top_tool} />
          </td>
          <td data-label="Most used model" className={`${cell} pr-0`}>
            {top_model ? <Top leader={top_model} /> : <p className="text-fg-muted">No model picked</p>}
          </td>
        </>
      ) : (
        <td colSpan={2} data-label="Most used" className={`${cell} pr-0 text-fg-muted`}>
          Nobody has ranked this yet
        </td>
      )}
    </tr>
  )
}

/** One row per kind of work: the most used tool and model, one runner-up each, and how stale the kind is. */
export default function WhatWeUseTable({ rows, show, now }: { rows: WhatWeUseRow[]; show: Show; now?: Date }) {
  const heading = `${sectionLabelClasses} py-3 text-left`

  return (
    <table className="stack-table w-full border-collapse">
      <thead>
        <tr className="border-b border-line">
          <th scope="col" className={`${heading} pr-4`}>
            Kind of work
          </th>
          <th scope="col" className={`${heading} px-4`}>
            Most used tool (the app)
          </th>
          <th scope="col" className={`${heading} pl-4`}>
            Most used model (the AI behind it)
          </th>
        </tr>
      </thead>
      <tbody>
        {rows.map((row) => (
          <Row key={row.category.slug} row={row} show={show} now={now} />
        ))}
      </tbody>
    </table>
  )
}
