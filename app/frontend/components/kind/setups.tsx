import type { Count as CountValue, MarkItem, PickContext, PickEffort } from '../../types'
import Chip, { contextLabel, effortLabel } from '../chip'
import Count from '../count'
import Mark from '../mark'

/** People who run one tool with one model at one context size and effort (blank ones are their own group). */
export type Setup = { tool: MarkItem; model: MarkItem; context: PickContext | null; effort: PickEffort | null; count: CountValue }

/** How we set them up: one row per tool, model, context and effort that people share. */
export default function Setups({ setups }: { setups: Setup[] }) {
  return (
    <section aria-label="How we set them up" className="mt-9">
      <h3 className="border-b border-line pb-1.5 text-caption text-fg-muted">How we set them up</h3>
      <ul>
        {setups.map(({ tool, model, context, effort, count }) => (
          <li
            key={`${tool.slug}-${model.slug}-${context}-${effort}`}
            className="stack-row border-b border-line py-3.5 md:flex md:flex-wrap md:items-center md:gap-x-6 md:gap-y-2"
          >
            <span className="flex items-center gap-3 md:w-[200px] lg:w-[220px]">
              <Mark item={tool} size="md" />
              <span className="font-semibold text-fg">{tool.name}</span>
            </span>
            <span className="mt-2 flex items-center gap-3 md:mt-0 md:w-[300px] lg:w-[320px]">
              <span className="text-fg-muted">with</span>
              <Mark item={model} size="md" />
              <span className="font-semibold text-fg">{model.name}</span>
            </span>
            {(context || effort) && (
              <span className="mt-2 flex flex-wrap items-center gap-2 md:mt-0 md:min-w-[230px] md:flex-1">
                {context && <Chip>{contextLabel(context)}</Chip>}
                {effort && <Chip>{effortLabel(effort)}</Chip>}
              </span>
            )}
            <Count count={count} label="use it" className="mt-2 block text-sm text-fg-soft md:ml-auto md:mt-0" />
          </li>
        ))}
      </ul>
    </section>
  )
}
