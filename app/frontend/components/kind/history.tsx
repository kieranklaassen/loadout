import type { Era } from '../../types'
import Mark from '../mark'

const day = (iso: string) => new Date(iso).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric', timeZone: 'UTC' })

/** The team's number-one tool and model over time, oldest first. Only the era that runs to today (`to` is null) is marked Now. */
export default function History({ eras }: { eras: Era[] }) {
  return (
    <ol className="flex flex-col gap-2 lg:flex-row lg:flex-wrap lg:gap-y-3">
      {eras.map((era, index) => {
        const current = era.to === null

        return (
          <li key={era.from} className="flex lg:min-w-[190px] lg:flex-1 lg:items-center">
            <div className={`panel flex-1 px-[18px] py-4 ${current ? 'border-yellow ring-1 ring-yellow' : ''}`}>
              <div className="flex items-baseline gap-2.5">
                <time dateTime={era.from} className="font-mono text-caption text-fg-soft">
                  {day(era.from)}
                </time>
                {current && <span className="font-mono text-xs uppercase tracking-[0.08em] text-yellow">Now</span>}
              </div>
              <div className="mt-3 flex items-center gap-2.5">
                <Mark item={era.tool} size="md" />
                <span className="font-semibold text-fg">{era.tool.name}</span>
              </div>
              <div className="mt-2 flex items-center gap-2 text-caption text-fg-muted">
                {era.model ? (
                  <>
                    <Mark item={era.model} size="xs" />
                    {era.model.name}
                  </>
                ) : (
                  'No model picked'
                )}
              </div>
            </div>
            {index < eras.length - 1 && (
              <span aria-hidden="true" className="hidden px-2 text-xl text-fg-muted lg:block">
                →
              </span>
            )}
          </li>
        )
      })}
    </ol>
  )
}
