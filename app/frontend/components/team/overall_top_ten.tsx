import type { Count as CountValue, MarkItem } from '../../types'
import Count from '../count'
import Mark from '../mark'

/** A tool or model and how many people use it. */
export type Standing = { item: MarkItem; count: CountValue }

export type Overall = { tools: Standing[]; models: Standing[] }

function Ranking({ title, note, standings }: { title: string; note: string; standings: Standing[] }) {
  return (
    <section aria-label={title}>
      <h3 className="font-serif text-[28px] leading-[1.1] tracking-[-0.01em] text-fg">{title}</h3>
      <p className="mt-1 text-caption text-fg-muted">{note}</p>
      <ol className="mt-4 border-t border-line">
        {standings.map(({ item, count }, index) => (
          <li key={item.slug} className="flex items-center gap-4 border-b border-line py-3">
            <span className={`w-6 shrink-0 font-mono text-caption tabular-nums ${index === 0 ? 'text-yellow' : 'text-fg-muted'}`}>{index + 1}</span>
            <Mark item={item} size="md" />
            <span className="min-w-0 flex-1 truncate font-semibold text-fg">{item.name}</span>
            <Count count={count} label="use it" className="shrink-0 text-caption text-fg-soft" />
          </li>
        ))}
      </ol>
    </section>
  )
}

/** The ten tools and the ten models the most people use, across every kind of work. */
export default function OverallTopTen({ overall }: { overall: Overall }) {
  return (
    <div className="grid gap-12 md:grid-cols-2 md:gap-16">
      <Ranking title="Tools" note="The apps we use" standings={overall.tools} />
      <Ranking title="Models" note="The AI behind them" standings={overall.models} />
    </div>
  )
}
