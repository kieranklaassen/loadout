import type { ReactNode } from 'react'
import {
  contextOptionLabel,
  effortOptionLabel,
  optionGroups,
  ordinal,
  toolsUsedElsewhere,
  type Catalog,
  type CatalogOption,
  type EditorKind,
  type Enums,
  type SlotView,
} from '../../lib/ranking'
import Chip from '../chip'
import Mark from '../mark'
import { sectionLabelClasses } from '../section_label'
import SuggestionSlot from './suggestion_slot'
import type { EditorActions, SlotFields } from './use_editor_actions'

const numeral = 'font-serif text-[28px] leading-none'
const rowButton =
  'text-link inline-flex min-h-11 items-center px-2 text-caption aria-disabled:cursor-not-allowed aria-disabled:opacity-50 md:min-h-0 md:py-1'

function SelectField({ id, label, mark, disabled, value, onChange, children }: {
  id: string
  label: string
  mark?: ReactNode
  disabled: boolean
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
        {mark}
        <select
          id={id}
          disabled={disabled}
          value={value}
          onChange={(event) => onChange(event.target.value)}
          className={`truncate ${value ? '' : 'text-fg-muted'}`}
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

function Options({ options, category, saved, label, disabled }: {
  options: CatalogOption[]
  category: EditorKind['category']
  saved: CatalogOption | null
  label: string
  disabled?: Set<string>
}) {
  const { suggested, rest } = optionGroups(options, category.slug, saved)
  const option = (item: CatalogOption) => (
    <option key={item.slug} value={item.slug} disabled={disabled?.has(item.slug)}>
      {item.name}
      {item.pending ? ' (pending review)' : ''}
    </option>
  )

  return (
    <>
      {suggested.length > 0 && <optgroup label={`Suggested for ${category.name}`}>{suggested.map(option)}</optgroup>}
      {rest.length > 0 && <optgroup label={label}>{rest.map(option)}</optgroup>}
    </>
  )
}

/** One of the three slots: a confirmed pick with its four selects, an empty slot, or a slot suggestions are waiting to fill. */
export default function Slot({ kind, view, catalog, enums, actions }: {
  kind: EditorKind
  view: SlotView
  catalog: Catalog
  enums: Enums
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
  const change = (fields: SlotFields) => actions.saveSlot(rank, fields)
  const toolItem = catalog.tools.find((item) => item.slug === shown.tool) ?? pick?.tool
  const modelItem = catalog.models.find((item) => item.slug === shown.model) ?? pick?.model
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
            <span className="sr-only">{ordinal(rank)} pick</span>
          </>
        ) : (
          <>
            <span aria-hidden="true" className={numeral}>
              {rank}
            </span>
            <span className="text-base font-semibold">Add your {ordinal(rank)} pick</span>
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
            <div className="slot-fields">
              <SelectField
                id={`slot-${rank}-tool`}
                label="Tool"
                mark={toolItem && <Mark item={toolItem} size="sm" />}
                disabled={false}
                value={shown.tool}
                onChange={(value) => value && change({ tool: value })}
              >
                {!pick && <option value="">Choose</option>}
                <Options options={catalog.tools} category={kind.category} saved={pick?.tool ? { ...pick.tool, suggested_for: [] } : null} label="All tools" disabled={toolsUsedElsewhere(kind, rank)} />
              </SelectField>
              <SelectField
                id={`slot-${rank}-model`}
                label={pick ? 'Model' : 'Model (optional)'}
                mark={modelItem && <Mark item={modelItem} size="sm" />}
                disabled={!pick}
                value={shown.model}
                onChange={(value) => change({ model: value || null })}
              >
                <option value="">Not set</option>
                <Options options={catalog.models} category={kind.category} saved={pick?.model ? { ...pick.model, suggested_for: [] } : null} label="All models" />
              </SelectField>
              <SelectField
                id={`slot-${rank}-context`}
                label="Context"
                disabled={!pick}
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
                    aria-disabled={rank === 1 || undefined}
                    onClick={() => rank !== 1 && actions.moveSlot(pick, 'up')}
                  >
                    Move up
                  </button>
                  <button
                    type="button"
                    className={rowButton}
                    aria-label={`Move ${pick.tool.name} down`}
                    aria-disabled={rank === kind.picks.length || undefined}
                    onClick={() => rank !== kind.picks.length && actions.moveSlot(pick, 'down')}
                  >
                    Move down
                  </button>
                  <button type="button" className={rowButton} aria-label={`Remove ${pick.tool.name}`} onClick={() => actions.removeSlot(pick)}>
                    Remove
                  </button>
                </div>
              )}
            </div>
            {status?.state === 'error' && (
              <p role="alert" className="mt-2 text-caption text-coral">
                {status.message}{' '}
                <button type="button" onClick={status.retry} className="text-link">
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
