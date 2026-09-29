import { Link } from '@inertiajs/react'
import type { ReactNode } from 'react'
import { rankLabel } from '../../lib/rank_label'
import { shortDate } from '../../lib/relative_date'
import type { Category, Launch, MarkItem, RankedPick } from '../../types'
import Chip, { contextLabel, effortLabel } from '../chip'
import Mark from '../mark'
import SectionLabel, { sectionLabelClasses } from '../section_label'
import VibeCheckLink from '../vibe_check_link'
import { kindHref, type Show } from './filters'

export type PersonKind = {
  category: Category
  picks: RankedPick[]
  team_uses: { tool: MarkItem | null; model: MarkItem | null } | null
}

export type PersonData = {
  person: { handle: string; name: string; avatar_url: string | null }
  ranked_count: number
  kinds: PersonKind[]
  new_in_toolbox: Launch[]
}

// The first pick of a kind that carries a team note is taller in both columns, so the tool and model lines stay level.
function Line({ rank, tall, mark, children, note }: { rank: number; tall: boolean; mark?: ReactNode; children: ReactNode; note?: MarkItem | null }) {
  return (
    <div className={`flex items-center gap-3 ${tall ? 'min-h-14' : 'min-h-12'}`}>
      <span className="w-8 shrink-0 font-mono text-caption text-fg-muted">{rankLabel(rank)}</span>
      {mark}
      <div className="min-w-0">
        <div className="flex flex-wrap items-center gap-x-2.5 gap-y-1">{children}</div>
        {note && <p className="text-caption text-fg-soft">Team's most used: {note.name}</p>}
      </div>
    </div>
  )
}

function ToolLine({ pick, tall, note }: { pick: RankedPick; tall: boolean; note?: MarkItem | null }) {
  return (
    <Line rank={pick.rank} tall={tall} mark={<Mark item={pick.tool} size="md" />} note={note}>
      <span className="font-medium text-fg">{pick.tool.name}</span>
      {pick.tool.pending && <Chip>Pending review</Chip>}
    </Line>
  )
}

function ModelLine({ pick, tall, note }: { pick: RankedPick; tall: boolean; note?: MarkItem | null }) {
  const { model, context, effort } = pick

  return (
    <Line rank={pick.rank} tall={tall} mark={model && <Mark item={model} size="md" />} note={note}>
      {model ? (
        <>
          <span className="font-medium text-fg">{model.name}</span>
          {model.pending && <Chip>Pending review</Chip>}
          {context && <Chip>{contextLabel(context)}</Chip>}
          {effort && <Chip>{effortLabel(effort)}</Chip>}
        </>
      ) : (
        <span className="text-fg-muted">No model picked</span>
      )}
    </Line>
  )
}

/** One person's ranked tools and models for every kind, with "Team's most used" where their first pick differs. */
export function PersonTable({ data, show }: { data: PersonData; show: Show }) {
  const { name } = data.person
  const heading = `${sectionLabelClasses} py-3 text-left`

  return (
    <table className="stack-table w-full border-collapse">
      <thead>
        <tr className="border-b border-line">
          <th scope="col" className={`${heading} pr-4`}>
            Kind of work
          </th>
          <th scope="col" className={`${heading} px-4`}>
            {name}'s tools (the app)
          </th>
          <th scope="col" className={`${heading} pl-4`}>
            {name}'s models (the AI behind it)
          </th>
        </tr>
      </thead>
      <tbody>
        {data.kinds.map(({ category, picks, team_uses }) => (
          <tr key={category.slug} className="border-b border-line">
            <th scope="row" className="w-[250px] py-5 pr-4 text-left align-top font-normal">
              <Link href={kindHref(category.slug, show)} className="block font-serif text-[22px] leading-[1.1] text-fg hover:underline">
                {category.name}
              </Link>
              <span className="mt-[3px] block text-caption text-fg-muted">{category.blurb}</span>
            </th>
            {picks.length === 0 ? (
              <td colSpan={2} data-label="Picks" className="px-4 py-5 pr-0 align-top text-fg-muted">
                Not ranked yet
              </td>
            ) : (
              <>
                <td data-label="Tools" className="w-[440px] px-4 py-3.5 align-top">
                  {picks.map((pick, index) => (
                    <ToolLine key={pick.rank} pick={pick} tall={index === 0 && team_uses !== null} note={index === 0 ? team_uses?.tool : null} />
                  ))}
                </td>
                <td data-label="Models" className="py-3.5 pl-4 align-top">
                  {picks.map((pick, index) => (
                    <ModelLine key={pick.rank} pick={pick} tall={index === 0 && team_uses !== null} note={index === 0 ? team_uses?.model : null} />
                  ))}
                </td>
              </>
            )}
          </tr>
        ))}
      </tbody>
    </table>
  )
}

/** Where a launched model sits in the person's toolbox: "2nd pick for Coding, in Claude Code". */
function placement(data: PersonData, launch: Launch) {
  for (const kind of data.kinds) {
    const pick = kind.picks.find((candidate) => candidate.model?.slug === launch.model.slug)
    if (pick) return `${rankLabel(pick.rank)} pick for ${kind.category.name}, in ${pick.tool.name}. `
  }
  return ''
}

/** The launched models this person has picked. Rendered only when there are some. */
export function NewInToolbox({ data }: { data: PersonData }) {
  if (data.new_in_toolbox.length === 0) return null

  return (
    <div className="panel w-full max-w-[520px] px-7 py-6">
      <SectionLabel as="p">New in {data.person.name}'s toolbox</SectionLabel>
      <ul className="divide-y divide-line">
        {data.new_in_toolbox.map((launch) => (
          <li key={launch.model.slug} className="py-4 first:pt-3.5 last:pb-0">
            <div className="flex items-center gap-3.5">
              <Mark item={launch.model} size="lg" />
              <span className="font-serif text-[28px] leading-[1.1] text-fg">{launch.model.name}</span>
            </div>
            <p className="mt-3 text-[15px] leading-[1.5] text-fg-soft">
              {placement(data, launch)}Out {shortDate(launch.released_on)}.
            </p>
            <VibeCheckLink url={launch.vibe_check_url} modelName={launch.model.name} className="mt-3 inline-block" />
          </li>
        ))}
      </ul>
    </div>
  )
}
