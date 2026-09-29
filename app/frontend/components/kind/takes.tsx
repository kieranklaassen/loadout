import type { MarkItem } from '../../types'
import Mark from '../mark'
import VibeCheckLink from '../vibe_check_link'

/** The Vibe Check of a launched model people ranked in this kind. The server has already checked the link. */
export type Take = { model: MarkItem; url: string }

/** Link-outs only: the takes live on Every's sign-in-gated Vibe Checks, so nothing from them is shown or fetched here. */
export default function Takes({ takes }: { takes: Take[] }) {
  return (
    <ul>
      {takes.map(({ model, url }) => (
        <li key={model.slug} className="flex flex-wrap items-center gap-x-4 gap-y-1 border-b border-line py-4">
          <Mark item={model} size="md" />
          <span className="min-w-[9rem] flex-1 font-semibold text-fg">{model.name}</span>
          <span className="flex w-full items-center justify-between gap-4 pl-[52px] md:w-auto md:pl-0">
            <span className="text-caption text-fg-muted">Sign-in required</span>
            <VibeCheckLink url={url} modelName={model.name} />
          </span>
        </li>
      ))}
    </ul>
  )
}
