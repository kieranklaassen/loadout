import { useEffect, useRef, useState, type ReactNode } from 'react'
import { rankLabel } from '../../lib/rank_label'
import { contextOptionLabel, effortOptionLabel } from '../../lib/ranking'
import type { MarkItem, PickContext, PickEffort, RankedPick, Suggestion } from '../../types'
import Button from '../button'
import Chip, { contextLabel, effortLabel } from '../chip'
import Mark from '../mark'
import { sectionLabelClasses } from '../section_label'
import type { EditorActions } from './use_editor_actions'

type Setup = { tool: MarkItem; model: MarkItem | null; context: PickContext | null; effort: PickEffort | null }

// 'empty': it would fill an empty slot. 'change': it changes the pick already in its slot.
// 'unplaced': the kind is full, so Confirm asks which pick to replace.
type Mode = 'empty' | 'change' | 'unplaced'

function Value({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="min-w-0">
      <dt className={`${sectionLabelClasses} mb-1.5`}>{label}</dt>
      <dd className="field-box">{children}</dd>
    </div>
  )
}

const NOT_SET = <span className="text-fg-muted">Not set</span>

function Item({ item }: { item: MarkItem }) {
  return (
    <>
      <Mark item={item} size="sm" />
      <span className="truncate">{item.name}</span>
    </>
  )
}

function SetupLine({ label, setup }: { label: string; setup: Setup }) {
  return (
    <p className="flex flex-wrap items-center gap-x-3 gap-y-1.5 text-[15px]">
      <span className={`${sectionLabelClasses} w-full md:w-24`}>{label}</span>
      <span className="flex items-center gap-2">
        <Mark item={setup.tool} size="xs" />
        {setup.tool.name}
      </span>
      {setup.model && (
        <span className="flex items-center gap-2">
          <Mark item={setup.model} size="xs" />
          {setup.model.name}
        </span>
      )}
      {setup.context && <Chip>{contextLabel(setup.context)}</Chip>}
      {setup.effort && <Chip>{effortLabel(setup.effort)}</Chip>}
    </p>
  )
}

/** An agent's suggested pick, with Confirm and Remove. Only the member can do either; the suggestion itself is never edited. */
export default function SuggestionSlot({ suggestion, mode, pick, picks, actions }: {
  suggestion: Suggestion
  mode: Mode
  pick: RankedPick | null
  picks: RankedPick[]
  actions: EditorActions
}) {
  const [choosing, setChoosing] = useState(false)
  const [choice, setChoice] = useState<number | null>(null)
  const confirmButton = useRef<HTMLButtonElement>(null)
  const firstRadio = useRef<HTMLInputElement>(null)
  const name = suggestion.tool.name

  useEffect(() => {
    if (choosing) firstRadio.current?.focus()
  }, [choosing])

  const confirm = () => {
    if (actions.busy) return
    if (mode === 'unplaced') return setChoosing(true)
    const rank = suggestion.target_rank ?? undefined
    actions.confirmSuggestion(suggestion, { rank }, suggestion.target_rank ?? 1)
  }

  const replace = () => {
    const chosen = picks.find((candidate) => candidate.rank === choice)
    if (!chosen) return
    actions.confirmSuggestion(suggestion, { rank: chosen.rank, expected: { tool: chosen.tool.slug, model: chosen.model?.slug ?? null } }, chosen.rank)
  }

  const cancel = () => {
    setChoosing(false)
    setChoice(null)
    confirmButton.current?.focus()
  }

  return (
    <div>
      <div className="flex flex-wrap items-center gap-x-4 gap-y-2">
        <p className="text-caption text-fg-soft">
          {mode === 'change' ? 'Suggested change' : 'Suggested'} by {suggestion.suggested_by}
        </p>
        <Button ref={confirmButton} aria-label={`Confirm ${name}`} aria-expanded={mode === 'unplaced' ? choosing : undefined} aria-disabled={actions.busy || undefined} onClick={confirm}>
          Confirm
        </Button>
      </div>

      {mode === 'change' && pick ? (
        <div className="mt-3 space-y-2">
          <SetupLine label="Now" setup={pick} />
          <SetupLine label="Suggested" setup={suggestion} />
        </div>
      ) : (
        <dl className="slot-fields mt-3">
          <Value label="Tool">
            <Item item={suggestion.tool} />
          </Value>
          <Value label="Model">{suggestion.model ? <Item item={suggestion.model} /> : NOT_SET}</Value>
          <Value label="Context">{suggestion.context ? contextOptionLabel(suggestion.context) : NOT_SET}</Value>
          <Value label="Effort">{suggestion.effort ? effortOptionLabel(suggestion.effort) : NOT_SET}</Value>
        </dl>
      )}

      {mode === 'unplaced' && !choosing && <p className="mt-3 text-caption text-fg-muted">All three slots are full. Confirming replaces one of your picks.</p>}

      {choosing && (
        <fieldset className="mt-4">
          <legend className={`${sectionLabelClasses} mb-2`}>Replace which pick?</legend>
          <div className="grid gap-2">
            {picks.map((candidate, index) => (
              <label key={candidate.rank} className="radio-card items-center">
                <input
                  ref={index === 0 ? firstRadio : undefined}
                  type="radio"
                  name={`replace-${suggestion.id}`}
                  checked={choice === candidate.rank}
                  onChange={() => setChoice(candidate.rank)}
                />
                <span className="radio-dot mt-0" />
                <span className="flex min-w-0 flex-wrap items-center gap-x-2 gap-y-1 text-[15px]">
                  <span className="text-fg-muted">{rankLabel(candidate.rank)}</span>
                  <Mark item={candidate.tool} size="xs" />
                  {candidate.tool.name}
                  {candidate.model && <span className="text-fg-muted">with {candidate.model.name}</span>}
                </span>
              </label>
            ))}
          </div>
          <div className="mt-3 flex gap-2">
            <Button disabled={choice === null} aria-disabled={actions.busy || undefined} onClick={replace}>
              Replace
            </Button>
            <Button variant="secondary" onClick={cancel}>
              Cancel
            </Button>
          </div>
        </fieldset>
      )}

      <div className="mt-3 flex justify-end">
        <button
          type="button"
          className="text-link min-h-11 px-2 text-caption aria-disabled:cursor-not-allowed aria-disabled:opacity-50 md:min-h-0"
          aria-label={`Remove suggested ${name}`}
          aria-disabled={actions.busy || undefined}
          onClick={() => actions.dismissSuggestion(suggestion)}
        >
          Remove
        </button>
      </div>
    </div>
  )
}
