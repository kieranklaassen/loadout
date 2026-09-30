import type { ReactNode } from 'react'
import { assemble, canAdd, modelForTool, modelSections, toolSections } from '../../lib/picker'
import { rankLabel } from '../../lib/rank_label'
import { contextOptionLabel, effortOptionLabel, type Catalog, type EditorKind, type Enums, type SlotView, type TeamTop } from '../../lib/ranking'
import Chip from '../chip'
import Combobox from '../combobox'
import { sectionLabelClasses } from '../section_label'
import SuggestionSlot from './suggestion_slot'
import type { EditorActions, SlotFields } from './use_editor_actions'

const numeral = 'font-serif text-[28px] leading-none'
const rowButton =
  'text-link inline-flex min-h-11 items-center px-2 text-caption aria-disabled:cursor-not-allowed aria-disabled:opacity-50 md:min-h-0 md:py-1'

// `busy` is a request in flight: the select stays focusable (`disabled` would drop focus) and the
// editor ignores a change, so the select shows the saved value again.
function SelectField({ id, label, disabled, busy, value, onChange, children }: {
  id: string
  label: string
  disabled: boolean
  busy: boolean
  value: string
  onChange: (value: string) => void
  children: ReactNode
}) {
  return (
    <div className="min-w-0">
      <label htmlFor={id} className={`${sectionLabelClasses} mb-1.5 block`}>
        {label}
      </label>
      <div className={`field-box ${disabled ? 'opacity-60' : ''}`}>
        <select
          id={id}
          disabled={disabled}
          aria-disabled={busy || undefined}
          value={value}
          onChange={(event) => onChange(event.target.value)}
          className={`-my-2.5 truncate py-2.5 ${value ? '' : 'text-fg-muted'}`}
        >
          {children}
        </select>
        <span aria-hidden="true" className="text-fg-muted">
          ▾
        </span>
      </div>
    </div>
  )
}

/** One of the three slots: a confirmed pick with its four selects, an empty slot, or a slot suggestions are waiting to fill. */
export default function Slot({ kind, view, catalog, enums, top, actions }: {
  kind: EditorKind
  view: SlotView
  catalog: Catalog
  enums: Enums
  /** What the team uses in this kind, to list the popular tools and models first. */
  top?: TeamTop[string]
  actions: EditorActions
}) {
  const { rank, pick, suggestions } = view
  const status = actions.statuses[rank]
  const draft: SlotFields = actions.drafts[rank] ?? {}
  const shown = {
    tool: draft.tool ?? pick?.tool.slug ?? '',
    model: 'model' in draft ? (draft.model ?? '') : (pick?.model?.slug ?? ''),
    context: 'context' in draft ? (draft.context ?? '') : (pick?.context ?? ''),
    effort: 'effort' in draft ? (draft.effort ?? '') : (pick?.effort ?? ''),
  }
  const change = (fields: SlotFields) => actions.saveSlot(rank, pick, fields)
  const toolOption = catalog.tools.find((item) => item.slug === shown.tool)
  const modelOption = catalog.models.find((item) => item.slug === shown.model)
  // A saved item the catalog no longer lists (an admin hid it) falls back to the pick; a draft
  // that is no slug of its own — cleared, or a name being added — must not snap back to it.
  const toolItem = toolOption ?? (shown.tool === pick?.tool.slug ? pick?.tool : undefined)
  const modelItem = modelOption ?? (shown.model === pick?.model?.slug ? pick?.model : undefined)
  const chooseTool = (slug: string) => change({ tool: slug, ...modelForTool(catalog.tools.find((item) => item.slug === slug), modelOption) })
  const waiting = !pick && suggestions.length > 0

  const surface = pick
    ? 'bg-panel ring-1 ring-line'
    : waiting
      ? 'border-[1.5px] border-dashed border-fg-muted'
      : 'border-[1.5px] border-dashed border-line-strong'

  return (
    <li className={`relative rounded-soft p-4 md:px-[18px] ${surface}`}>
      <h3
        id={`slot-heading-${rank}`}
        tabIndex={-1}
        className={pick || waiting ? `${numeral} mb-3 md:absolute md:left-[18px] md:mb-0 ${pick ? 'md:top-[38px]' : 'md:top-[18px]'}` : 'mb-3 flex items-center gap-4 text-fg-soft'}
      >
        {pick || waiting ? (
          <>
            <span aria-hidden="true">{rank}</span>
            <span className="sr-only">{rankLabel(rank)} pick</span>
          </>
        ) : (
          <>
            <span aria-hidden="true" className={numeral}>
              {rank}
            </span>
            <span className="text-base font-semibold">Add your {rankLabel(rank)} pick</span>
          </>
        )}
      </h3>

      <div role="group" aria-labelledby={`slot-heading-${rank}`} className="md:pl-[50px]">
        {waiting ? (
          <div className="space-y-3">
            {suggestions.map((suggestion, index) => (
              <div key={suggestion.id} className={index > 0 ? 'border-t border-line pt-3' : ''}>
                <SuggestionSlot suggestion={suggestion} mode="empty" pick={null} picks={kind.picks} actions={actions} />
              </div>
            ))}
          </div>
        ) : (
          <>
            <div className="slot-fields relative">
              <Combobox
                id={`slot-${rank}-tool`}
                label="Tool"
                placeholder="Choose"
                selected={toolItem}
                busy={actions.busy}
                showAllLabel="Show all tools"
                list={(query, showAll) => assemble(toolSections({ tools: catalog.tools, kind, rank, saved: toolItem, standings: top?.tools }), query, showAll)}
                canAdd={canAdd}
                onSelect={(slug) => slug && chooseTool(slug)}
                onAdd={(name) => change({ tool: name })}
              />
              <Combobox
                id={`slot-${rank}-model`}
                label={pick ? 'Model' : 'Model (optional)'}
                placeholder="Not set"
                selected={modelItem}
                disabled={!pick}
                busy={actions.busy}
                clearLabel="Not set"
                showAllLabel="Show all models"
                list={(query, showAll) =>
                  assemble(modelSections({ models: catalog.models, tool: toolOption, category: kind.category, saved: modelItem, standings: top?.models }), query, showAll)
                }
                canAdd={canAdd}
                onSelect={(slug) => change({ model: slug })}
                onAdd={(name) => change({ model: name })}
              />
              <SelectField
                id={`slot-${rank}-context`}
                label="Context"
                disabled={!pick}
                busy={actions.busy}
                value={shown.context}
                onChange={(value) => change({ context: (value || null) as SlotFields['context'] })}
              >
                <option value="">Not set</option>
                {enums.context.map((value) => (
                  <option key={value} value={value}>
                    {contextOptionLabel(value)}
                  </option>
                ))}
              </SelectField>
              <SelectField
                id={`slot-${rank}-effort`}
                label="Effort"
                disabled={!pick}
                busy={actions.busy}
                value={shown.effort}
                onChange={(value) => change({ effort: (value || null) as SlotFields['effort'] })}
              >
                <option value="">Not set</option>
                {enums.effort.map((value) => (
                  <option key={value} value={value}>
                    {effortOptionLabel(value)}
                  </option>
                ))}
              </SelectField>
            </div>

            <div className="mt-3 flex flex-wrap items-center justify-between gap-x-4 gap-y-1">
              <div className="flex flex-wrap items-center gap-x-3 gap-y-1 text-caption text-fg-soft">
                <p role="status" aria-live="polite">
                  {status?.state === 'saving' && 'Saving…'}
                  {status?.state === 'saved' && 'Saved'}
                  {!status && pick && (
                    <>
                      <span aria-hidden="true">● </span>Confirmed
                    </>
                  )}
                </p>
                {(pick?.tool.pending || pick?.model?.pending) && <Chip>Pending review</Chip>}
              </div>
              {pick && (
                <div className="-mr-2 flex flex-wrap items-center">
                  <button
                    type="button"
                    className={rowButton}
                    aria-label={`Move ${pick.tool.name} up`}
                    aria-disabled={rank === 1 || actions.busy || undefined}
                    onClick={() => rank !== 1 && actions.moveSlot(pick, 'up')}
                  >
                    Move up
                  </button>
                  <button
                    type="button"
                    className={rowButton}
                    aria-label={`Move ${pick.tool.name} down`}
                    aria-disabled={rank === kind.picks.length || actions.busy || undefined}
                    onClick={() => rank !== kind.picks.length && actions.moveSlot(pick, 'down')}
                  >
                    Move down
                  </button>
                  <button type="button" className={rowButton} aria-label={`Remove ${pick.tool.name}`} aria-disabled={actions.busy || undefined} onClick={() => actions.removeSlot(pick)}>
                    Remove
                  </button>
                </div>
              )}
            </div>
            {status?.state === 'error' && (
              <p role="alert" className="mt-2 text-caption text-coral">
                {status.message}{' '}
                <button type="button" onClick={status.retry} aria-disabled={actions.busy || undefined} className="text-link aria-disabled:cursor-not-allowed aria-disabled:opacity-50">
                  Retry
                </button>
              </p>
            )}

            {pick &&
              suggestions.map((suggestion) => (
                <div key={suggestion.id} className="mt-4 rounded-soft border border-dashed border-fg-muted p-3">
                  <SuggestionSlot suggestion={suggestion} mode="change" pick={pick} picks={kind.picks} actions={actions} />
                </div>
              ))}
          </>
        )}
      </div>
    </li>
  )
}
