import type { ReactNode } from 'react'
import type { Category, MarkItem, RankedPick } from '../../types'
import Chip, { contextLabel, effortLabel } from '../chip'
import Mark from '../mark'
import { sectionLabelClasses } from '../section_label'

export type ProfileKind = { category: Category; picks: RankedPick[] }

const itemName = 'text-[17px] font-semibold leading-[1.2] text-fg'
const cell = 'px-4 py-[22px] align-middle'

/** The viewer's value under the person's, for a phone, where the You column is hidden. */
function YouLine({ children }: { children: ReactNode }) {
  return (
    <p className="mt-3 text-caption text-fg-muted md:hidden">
      You: <span className="text-fg-soft">{children}</span>
    </p>
  )
}

function ToolCell({ picks, comparing, mine }: { picks: RankedPick[]; comparing: boolean; mine?: RankedPick }) {
  const [first, ...later] = picks

  return (
    <td data-label="Tool" className={cell}>
      <div className="flex items-center gap-3.5">
        <Mark item={first.tool} size="lg" />
        <div className="min-w-0">
          <p className="flex flex-wrap items-center gap-x-2.5 gap-y-1">
            <span className={itemName}>{first.tool.name}</span>
            {first.tool.pending && <Chip>Pending review</Chip>}
          </p>
          {later.length > 0 && <p className="mt-[3px] text-caption text-fg-muted">then {later.map((pick) => pick.tool.name).join(', ')}</p>}
        </div>
      </div>
      {comparing && <YouLine>{mine ? mine.tool.name : 'Not ranked'}</YouLine>}
    </td>
  )
}

function ModelCell({ pick, comparing, mine }: { pick: RankedPick; comparing: boolean; mine?: RankedPick }) {
  const { model, context, effort } = pick

  return (
    <td data-label="Model" className={cell}>
      <div className="flex items-center gap-3.5">
        {model && <Mark item={model} size="lg" />}
        <div className="min-w-0">
          {model ? (
            <p className="flex flex-wrap items-center gap-x-2.5 gap-y-1">
              <span className={itemName}>{model.name}</span>
              {model.pending && <Chip>Pending review</Chip>}
            </p>
          ) : (
            <p className="text-fg-muted">No model picked</p>
          )}
          {(context || effort) && (
            <div className="mt-1.5 flex flex-wrap gap-1.5">
              {context && <Chip>{contextLabel(context)}</Chip>}
              {effort && <Chip>{effortLabel(effort)}</Chip>}
            </div>
          )}
        </div>
      </div>
      {comparing && mine && <YouLine>{mine.model ? mine.model.name : 'No model picked'}</YouLine>}
    </td>
  )
}

function YouItem({ item }: { item: MarkItem }) {
  return (
    <div className="flex items-center gap-3">
      <Mark item={item} size="md" />
      <span className="text-[15px] font-semibold leading-[1.2] text-fg">{item.name}</span>
    </div>
  )
}

/** The viewer's first tool and model for the kind, from 768px; a phone reads them in the cells beside it. */
function YouCell({ mine }: { mine?: RankedPick }) {
  return (
    <td data-label="You" className={`${cell} hidden md:table-cell`}>
      {mine ? (
        <div className="flex flex-col gap-2.5">
          <YouItem item={mine.tool} />
          {mine.model ? <YouItem item={mine.model} /> : <p className="text-fg-muted">No model picked</p>}
        </div>
      ) : (
        <p className="text-fg-muted">Not ranked</p>
      )}
    </td>
  )
}

/**
 * One row per kind the person ranked: their first tool and model large, later tools in a
 * "then" line. `you` is the viewer's picks by kind slug while Compare with mine is on
 * (null otherwise): it adds a You column, and a kind the viewer did not rank reads "Not
 * ranked". A kind only the viewer ranked has no row.
 */
export default function LoadoutTable({ kinds, you }: { kinds: ProfileKind[]; you: Record<string, RankedPick[]> | null }) {
  const heading = `${sectionLabelClasses} py-3 text-left`

  return (
    <table className="stack-table w-full border-collapse">
      <thead>
        <tr className="border-b border-line">
          <th scope="col" className={`${heading} pr-4`}>
            Kind of work
          </th>
          <th scope="col" className={`${heading} px-4`}>
            Tool
          </th>
          <th scope="col" className={`${heading} px-4`}>
            Model
          </th>
          {you && (
            <th scope="col" className={`${heading} hidden px-4 md:table-cell`}>
              You
            </th>
          )}
        </tr>
      </thead>
      <tbody>
        {kinds.map(({ category, picks }) => {
          const mine = you?.[category.slug]?.[0]

          return (
            <tr key={category.slug} className="border-b border-line">
              <th scope="row" className="w-[240px] py-[22px] pr-4 text-left align-middle font-normal">
                <span className="font-serif text-2xl leading-[1.1] text-fg">{category.name}</span>
              </th>
              <ToolCell picks={picks} comparing={you !== null} mine={mine} />
              <ModelCell pick={picks[0]} comparing={you !== null} mine={mine} />
              {you && <YouCell mine={mine} />}
            </tr>
          )
        })}
      </tbody>
    </table>
  )
}
