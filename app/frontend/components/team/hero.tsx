import { useEffect, useState, type CSSProperties } from 'react'
import { rankLabel } from '../../lib/rank_label'
import { shortDate } from '../../lib/relative_date'
import type { Category, MarkItem } from '../../types'
import Mark from '../mark'
import { sectionLabelClasses } from '../section_label'
import './hero.css'

export type HeroPick = { rank: number; tool: MarkItem; model: MarkItem | null }

export type HeroData = {
  boards: { category: Category; picks: HeroPick[] }[]
  people: number
  picks: number
  last_update_at: string | null
}

const reducedMotion = () => typeof window !== 'undefined' && window.matchMedia?.('(prefers-reduced-motion: reduce)').matches === true

const plural = (count: number, one: string, many: string) => `${count} ${count === 1 ? one : many}`

const index = (name: string, value: number) => ({ [name]: value }) as CSSProperties

/** A looping picture of the team's busiest kinds. Decorative: the caption says what it shows, and it stills itself under reduced motion. */
export default function Hero({ hero }: { hero: HeroData }) {
  const { boards, people, picks, last_update_at } = hero
  const animated = boards.length > 1
  // Starts playing on the server and the client alike so hydration matches; a
  // reduced-motion browser stills it right after mount.
  const [playing, setPlaying] = useState(true)
  useEffect(() => {
    if (reducedMotion()) setPlaying(false)
  }, [])

  if (boards.length === 0) return null

  return (
    <figure className="flex flex-col items-start gap-2.5 lg:items-end">
      <div
        aria-hidden="true"
        data-playing={animated && playing}
        data-boards={boards.length}
        className="hero dot-grid relative h-[330px] w-full max-w-[520px] overflow-hidden rounded-soft bg-field ring-1 ring-line"
      >
        {boards.map((board, i) => (
          <div key={board.category.slug} className="hero-board absolute inset-x-6 top-5" style={index('--i', i)}>
            <div className="mb-1.5 flex items-baseline justify-between border-b border-line pb-2.5">
              <span className="font-serif text-[30px] leading-none text-fg">{board.category.name}</span>
              <span className={sectionLabelClasses}>Tool · Model</span>
            </div>
            {board.picks.map((pick, j) => (
              <div key={pick.rank} className="hero-pick flex h-14 items-center gap-3" style={index('--j', j)}>
                <span className={`w-[30px] font-mono text-caption ${pick.rank === 1 ? 'text-yellow' : 'text-fg-muted'}`}>{rankLabel(pick.rank)}</span>
                <Mark item={pick.tool} size="md" />
                <span className="w-[104px] shrink-0 truncate font-semibold text-fg">{pick.tool.name}</span>
                {pick.model ? (
                  <span className="flex min-w-0 items-center gap-2">
                    <Mark item={pick.model} size="xs" />
                    <span className="truncate text-sm text-fg-soft">{pick.model.name}</span>
                  </span>
                ) : (
                  <span className="text-sm text-fg-muted">No model</span>
                )}
              </div>
            ))}
          </div>
        ))}
        {animated && (
          <div className="absolute bottom-4 left-6 flex gap-1.5">
            {boards.map((board, i) => (
              <span key={board.category.slug} className="hero-dot relative h-[3px] w-[22px] bg-fg/25">
                <span className="hero-dot-lit absolute inset-0 bg-fg opacity-0" style={index('--i', i)} />
              </span>
            ))}
          </div>
        )}
      </div>
      <figcaption className="flex flex-wrap items-center gap-x-4 gap-y-1 font-mono text-caption text-fg-soft">
        <span>
          {plural(people, 'person', 'people')} ranked {plural(picks, 'pick', 'picks')}
          {last_update_at && ` · Last update ${shortDate(last_update_at)}`}
        </span>
        {animated && (
          <button type="button" className="text-link min-h-11 md:min-h-0" onClick={() => setPlaying((value) => !value)}>
            {playing ? 'Pause animation' : 'Play animation'}
          </button>
        )}
      </figcaption>
    </figure>
  )
}
