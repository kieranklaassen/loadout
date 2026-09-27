import { shortDate } from '../../lib/relative_date'
import type { Launch } from '../../types'
import Chip from '../chip'
import Count from '../count'
import Mark from '../mark'

/** A model launch: name, date, how many use it, and the fixed-text Vibe Check link-out. Nothing here is invented; the server lists a launch only with a date and a valid link. */
export default function LaunchRow({ launch }: { launch: Launch }) {
  const { model, released_on, vibe_check_url, newest, adoption, mostly_in } = launch

  return (
    <li className="stack-row items-center gap-x-6 gap-y-2 border-b border-line py-[18px] md:grid md:grid-cols-[minmax(0,340px)_170px_minmax(0,1fr)_auto]">
      <span className="flex items-center gap-3.5">
        <Mark item={model} size="lg" />
        <span className="font-serif text-[28px] leading-[1.1] text-fg">{model.name}</span>
      </span>
      <span className="mt-2 flex items-center gap-2.5 md:mt-0">
        {newest && <Chip tone="newest">Newest</Chip>}
        <time dateTime={released_on} className="font-mono text-caption text-fg-muted">
          {shortDate(released_on)}
        </time>
      </span>
      <span className="mt-2 block text-base text-fg md:mt-0">
        {adoption.of > 0 && (
          <>
            <Count count={adoption} label="use it" />
            {mostly_in && `, mostly in ${mostly_in.name}`}
          </>
        )}
      </span>
      <a
        href={vibe_check_url}
        target="_blank"
        rel="noopener noreferrer"
        aria-label={`Vibe Check for ${model.name}`}
        className="text-link mt-3 inline-block text-sm md:mt-0"
      >
        Vibe Check <span aria-hidden="true">↗</span>
      </a>
    </li>
  )
}
