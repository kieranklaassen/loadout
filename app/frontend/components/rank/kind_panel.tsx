import { layoutSlots, type Catalog, type EditorKind, type Enums, type TeamTop } from '../../lib/ranking'
import ConnectAgentCard from '../connect_agent_card'
import AddItem from './add_item'
import Slot from './slot'
import SuggestionSlot from './suggestion_slot'
import TeamList from './team_list'
import { useEditorActions } from './use_editor_actions'

/** One kind of work: its three slots, the suggestions waiting on the member, the agent card and the team's picks. */
export default function KindPanel({ kind, catalog, enums, teamTop }: {
  kind: EditorKind
  catalog: Catalog
  enums: Enums
  teamTop: TeamTop
}) {
  const actions = useEditorActions(kind.category.slug)
  const { slots, unplaced } = layoutSlots(kind)
  // A suggestion that asked which pick to replace starts over when the picks change under it.
  const picksKey = kind.picks.map((pick) => `${pick.rank}${pick.tool.slug}${pick.model?.slug ?? ''}`).join('.')

  return (
    <section aria-labelledby="kind-heading" className="min-w-0 flex-1">
      <div className="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1">
        <h2 id="kind-heading" tabIndex={-1} className="font-serif text-[32px] leading-[1.02] tracking-[-0.02em] md:text-[40px]">
          {kind.category.name}
        </h2>
        <p className="text-sm text-fg-muted">{kind.category.blurb}</p>
      </div>

      {actions.suggestionError && (
        <p role="alert" className="mt-3 text-caption text-coral">
          {actions.suggestionError}
        </p>
      )}

      <ol className="mt-4 flex flex-col gap-3">
        {slots.map((view) => (
          <Slot key={view.rank} kind={kind} view={view} catalog={catalog} enums={enums} top={teamTop[kind.category.slug]} actions={actions} />
        ))}
      </ol>

      {unplaced.length > 0 && (
        <ul className="mt-3 flex flex-col gap-3">
          {unplaced.map((suggestion) => (
            <li key={`${suggestion.id}-${picksKey}`} className="rounded-soft border-[1.5px] border-dashed border-fg-muted p-4">
              <SuggestionSlot suggestion={suggestion} mode="unplaced" pick={null} picks={kind.picks} actions={actions} />
            </li>
          ))}
        </ul>
      )}

      <p role="status" aria-live="polite" className="sr-only">
        {actions.announcement}
      </p>

      <ConnectAgentCard compact className="mt-5" />
      <TeamList kind={kind} top={teamTop[kind.category.slug]} actions={actions} />
      <AddItem catalog={catalog} />
    </section>
  )
}
