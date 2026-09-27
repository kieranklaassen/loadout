import type { ReactNode } from 'react'
import { modelAction, ordinal, teamCountText, toolAction, type EditorKind, type TeamAction, type TeamStanding, type TeamTop } from '../../lib/ranking'
import Button from '../button'
import Mark from '../mark'
import { sectionLabelClasses } from '../section_label'
import type { EditorActions } from './use_editor_actions'

function Column({ title, empty, children }: { title: string; empty: string; children: ReactNode[] }) {
  return (
    <div>
      <h4 className={`${sectionLabelClasses} border-b border-line pb-2`}>{title}</h4>
      {children.length > 0 ? <ul>{children}</ul> : <p className="py-3 text-caption text-fg-muted">{empty}</p>}
    </div>
  )
}

function Row({ standing, launched, action, onUse }: {
  standing: TeamStanding
  launched?: boolean
  action: TeamAction | null
  onUse: (action: Extract<TeamAction, { type: 'use' }>) => void
}) {
  return (
    <li className="flex items-center gap-3 border-b border-line py-3">
      <Mark item={standing.item} size="md" />
      <div className="min-w-0 flex-1">
        <p className="truncate text-[15px] font-semibold">{standing.item.name}</p>
        <p className="mt-0.5 text-caption text-fg-muted">{teamCountText(standing, launched)}</p>
      </div>
      {action?.type === 'have' && <span className="text-caption text-fg-muted">{action.text}</span>}
      {action?.type === 'use' && (
        <Button variant="secondary" aria-label={`${action.label}: ${standing.item.name}`} onClick={() => onUse(action)}>
          {action.label}
        </Button>
      )}
    </li>
  )
}

/** What the audience uses in this kind, with a button to take an item into the first open slot. */
export default function TeamList({ kind, top, actions }: { kind: EditorKind; top: TeamTop[string] | undefined; actions: EditorActions }) {
  const tools = top?.tools ?? []
  const models = top?.models ?? []
  const kindName = kind.category.name.toLowerCase()

  return (
    <section aria-labelledby="team-heading" className="mt-12 md:mt-16">
      <h3 id="team-heading" className="font-serif text-[28px] leading-[1.1] tracking-[-0.02em]">
        What the team uses for {kind.category.name}
      </h3>

      {tools.length === 0 && models.length === 0 ? (
        <p className="mt-4 text-fg-soft">Nobody has ranked {kindName} yet</p>
      ) : (
        <div className="mt-4 grid gap-8 md:grid-cols-2 md:gap-12">
          <Column title="Tools the team uses" empty={`Nobody has ranked a tool for ${kindName} yet`}>
            {tools.map((standing) => (
              <Row
                key={standing.item.slug}
                standing={standing}
                action={toolAction(kind, standing)}
                onUse={(action) =>
                  actions.saveSlot(action.rank, { tool: standing.item.slug }, { message: `${standing.item.name} is now your ${ordinal(action.rank)} pick` })
                }
              />
            ))}
          </Column>
          <Column title="Models the team uses" empty={`Nobody has ranked a model for ${kindName} yet`}>
            {models.map((standing) => (
              <Row
                key={standing.item.slug}
                standing={standing}
                launched={standing.launched}
                action={modelAction(kind, standing)}
                onUse={(action) =>
                  actions.saveSlot(action.rank, { model: standing.item.slug }, { message: `${standing.item.name} is now the model for your ${ordinal(action.rank)} pick` })
                }
              />
            ))}
          </Column>
        </div>
      )}
    </section>
  )
}
