import type { Page, VisitOptions } from '@inertiajs/core'
import { router } from '@inertiajs/react'
import { useEffect, useState } from 'react'
import { movedMessage, ordinal } from '../../lib/ranking'
import type { PickContext, PickEffort, RankedPick, SharedProps, Suggestion } from '../../types'

// Every write the Rank editor makes goes through here: a slot save, a move, a removal,
// and confirming or dismissing a suggestion. Each is an Inertia visit to the web
// endpoints (PATCH /loadout, POST and DELETE /loadout/suggestions/:id) that redirects
// back with fresh props, so the page never holds a second copy of the loadout. The
// hook tracks what to show while a request is out, what to say when it is refused, and
// where focus and the live region should go afterwards.

const LOADOUT = '/loadout'
const REFUSED = 'That did not save. Try again.'

/** The fields one slot can change; a key left out keeps the slot's value and null clears it. */
export type SlotFields = { tool?: string; model?: string | null; context?: PickContext | null; effort?: PickEffort | null }

export type SlotStatus = { state: 'saving' } | { state: 'saved' } | { state: 'error'; message: string; retry: () => void }

/** The pick the member was shown in the slot a confirm replaces: { tool, model } by slug. */
export type ConfirmOptions = { rank?: number; expected?: { tool: string; model: string | null } }

type Outcome = { onSaved: () => void; onFailed: (message: string) => void }
type Send = (options: VisitOptions) => void

export type EditorActions = ReturnType<typeof useEditorActions>

export function useEditorActions(category: string) {
  // What the selects show while a save is out; dropped when it succeeds or is refused, which reverts them.
  const [drafts, setDrafts] = useState<Record<number, SlotFields>>({})
  const [statuses, setStatuses] = useState<Record<number, SlotStatus | null>>({})
  const [suggestionError, setSuggestionError] = useState<string | null>(null)
  const [announcement, setAnnouncement] = useState('')
  const [focus, setFocus] = useState<{ id: string } | null>(null)

  useEffect(() => {
    if (focus) document.getElementById(focus.id)?.focus()
  }, [focus])

  const status = (rank: number, value: SlotStatus | null) => setStatuses((current) => ({ ...current, [rank]: value }))
  const settle = (rank: number) => setDrafts(({ [rank]: _dropped, ...rest }) => rest)
  const focusSlot = (rank: number) => setFocus({ id: `slot-heading-${rank}` })

  // A refusal comes back as a flash alert on the page the server redirects to; a request that
  // never got an answer arrives as an error callback. Either way the editor says so inline, so
  // the alert banner is cleared instead of saying it twice.
  const run = (send: Send, { onSaved, onFailed }: Outcome) =>
    send({
      preserveScroll: true,
      preserveState: true,
      onSuccess: (page: Page) => {
        const alert = (page.props as Partial<SharedProps>).flash?.alert
        if (!alert) return onSaved()
        router.replaceProp('flash', {})
        onFailed(alert)
      },
      onError: (errors) => onFailed(String(Object.values(errors)[0] ?? REFUSED)),
      onNetworkError: () => onFailed(REFUSED),
      onHttpException: () => onFailed(REFUSED),
    })

  const saveSlot = (rank: number, fields: SlotFields, then?: { message: string }) => {
    setDrafts((current) => ({ ...current, [rank]: { ...current[rank], ...fields } }))
    status(rank, { state: 'saving' })
    run((options) => router.patch(LOADOUT, { operations: [{ op: 'set_pick', category, rank, ...fields }] }, options), {
      onSaved: () => {
        settle(rank)
        status(rank, { state: 'saved' })
        if (then) {
          setAnnouncement(then.message)
          focusSlot(rank)
        }
      },
      onFailed: (message) => {
        settle(rank)
        status(rank, { state: 'error', message, retry: () => saveSlot(rank, fields, then) })
      },
    })
  }

  const moveSlot = (pick: RankedPick, direction: 'up' | 'down') => {
    const to = pick.rank + (direction === 'up' ? -1 : 1)
    status(pick.rank, { state: 'saving' })
    run((options) => router.patch(LOADOUT, { operations: [{ op: 'move_pick', category, rank: pick.rank, direction }] }, options), {
      onSaved: () => {
        status(pick.rank, null)
        status(to, { state: 'saved' })
        setAnnouncement(movedMessage(pick.tool.name, to))
        focusSlot(to)
      },
      onFailed: (message) => status(pick.rank, { state: 'error', message, retry: () => moveSlot(pick, direction) }),
    })
  }

  const removeSlot = (pick: RankedPick) => {
    status(pick.rank, { state: 'saving' })
    run((options) => router.patch(LOADOUT, { operations: [{ op: 'remove_pick', category, rank: pick.rank }] }, options), {
      onSaved: () => {
        status(pick.rank, null)
        setAnnouncement(`Removed ${pick.tool.name} from your ${ordinal(pick.rank)} pick`)
        focusSlot(pick.rank)
      },
      onFailed: (message) => status(pick.rank, { state: 'error', message, retry: () => removeSlot(pick) }),
    })
  }

  // `landing` is the slot the pick ends up in, for the announcement and focus.
  const confirmSuggestion = (suggestion: Suggestion, options: ConfirmOptions, landing: number) => {
    setSuggestionError(null)
    run((visit) => router.post(`${LOADOUT}/suggestions/${suggestion.id}/confirm`, options, visit), {
      onSaved: () => {
        setAnnouncement(`Confirmed ${suggestion.tool.name} as your ${ordinal(landing)} pick`)
        focusSlot(landing)
      },
      onFailed: setSuggestionError,
    })
  }

  const dismissSuggestion = (suggestion: Suggestion) => {
    setSuggestionError(null)
    run((visit) => router.delete(`${LOADOUT}/suggestions/${suggestion.id}`, visit), {
      onSaved: () => {
        setAnnouncement(`Removed the suggestion of ${suggestion.tool.name}`)
        if (suggestion.target_rank) focusSlot(suggestion.target_rank)
        else setFocus({ id: 'kind-heading' })
      },
      onFailed: setSuggestionError,
    })
  }

  return { drafts, statuses, suggestionError, announcement, saveSlot, moveSlot, removeSlot, confirmSuggestion, dismissSuggestion }
}
