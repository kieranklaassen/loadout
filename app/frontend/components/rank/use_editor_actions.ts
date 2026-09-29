import type { Page, VisitOptions } from '@inertiajs/core'
import { router } from '@inertiajs/react'
import { useEffect, useRef, useState } from 'react'
import { rankLabel } from '../../lib/rank_label'
import { movedMessage } from '../../lib/ranking'
import type { PickContext, PickEffort, RankedPick, SharedProps, Suggestion } from '../../types'

// Every write the Rank editor makes goes through here: a slot save, a move, a removal,
// and confirming or dismissing a suggestion. Each is an Inertia visit to the web
// endpoints (PATCH /toolbox, POST and DELETE /toolbox/suggestions/:id) that redirects
// back with fresh props, so the page never holds a second copy of the toolbox. The
// hook tracks what to show while a request is out, what to say when it is refused, and
// where focus and the live region should go afterwards.
//
// One request at a time: Inertia keeps a single app-wide queue for visits and a new one
// cancels the one in flight, and every write here addresses a pick by its rank, which a
// removal or a move changes. So while a request is out `busy` is true and every action
// below ignores new calls; the controls show it (aria-disabled) instead of hiding.
//
// Each slot write also sends `expected_tool`: the tool the member was shown in that slot,
// from the props and never a draft, or null for an empty one. If the slot holds anything
// else by then the server refuses with "This changed, review it.", so a Retry (which sends
// the same expectation) or a stale second tab cannot hit the pick that moved into that rank.

const TOOLBOX = '/toolbox'
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
  // The ref decides, so two calls in one tick cannot both pass; the state is for rendering.
  const inFlight = useRef(false)
  const [busy, setBusy] = useState(false)

  useEffect(() => {
    if (focus) document.getElementById(focus.id)?.focus()
  }, [focus])

  const status = (rank: number, value: SlotStatus | null) => setStatuses((current) => ({ ...current, [rank]: value }))
  const settle = (rank: number) => setDrafts(({ [rank]: _dropped, ...rest }) => rest)
  const focusSlot = (rank: number) => setFocus({ id: `slot-heading-${rank}` })

  const setInFlight = (value: boolean) => {
    inFlight.current = value
    setBusy(value)
  }
  const whenIdle =
    <Args extends unknown[]>(action: (...args: Args) => void) =>
    (...args: Args) => {
      if (!inFlight.current) action(...args)
    }

  // A refusal comes back as a flash alert on the page the server redirects to; a request that
  // never got an answer arrives as an error callback. Either way the editor says so inline, so
  // the alert banner is cleared instead of saying it twice. A visit another part of the page
  // cancelled reports neither, only that it finished, and counts as a request without an answer.
  const run = (send: Send, { onSaved, onFailed }: Outcome) => {
    let answered = false
    const answer = (outcome: () => void) => {
      if (answered) return
      answered = true
      setInFlight(false)
      outcome()
    }

    setInFlight(true)
    send({
      preserveScroll: true,
      preserveState: true,
      onSuccess: (page: Page) =>
        answer(() => {
          const alert = (page.props as Partial<SharedProps>).flash?.alert
          if (!alert) return onSaved()
          router.replaceProp('flash', {})
          onFailed(alert)
        }),
      onError: (errors) => answer(() => onFailed(String(Object.values(errors)[0] ?? REFUSED))),
      onNetworkError: () => answer(() => onFailed(REFUSED)),
      onHttpException: () => answer(() => onFailed(REFUSED)),
      onFinish: () => answer(() => onFailed(REFUSED)),
    })
  }

  // `shown` is the pick the member saw in the slot, or null when it was empty.
  const saveSlot = whenIdle((rank: number, shown: RankedPick | null, fields: SlotFields, then?: { message: string }) => {
    setDrafts((current) => ({ ...current, [rank]: { ...current[rank], ...fields } }))
    status(rank, { state: 'saving' })
    run((options) => router.patch(TOOLBOX, { operations: [{ op: 'set_pick', category, rank, ...fields, expected_tool: shown?.tool.slug ?? null }] }, options), {
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
        status(rank, { state: 'error', message, retry: () => saveSlot(rank, shown, fields, then) })
      },
    })
  })

  const moveSlot = whenIdle((pick: RankedPick, direction: 'up' | 'down') => {
    const to = pick.rank + (direction === 'up' ? -1 : 1)
    status(pick.rank, { state: 'saving' })
    run((options) => router.patch(TOOLBOX, { operations: [{ op: 'move_pick', category, rank: pick.rank, direction, expected_tool: pick.tool.slug }] }, options), {
      onSaved: () => {
        status(pick.rank, null)
        status(to, { state: 'saved' })
        setAnnouncement(movedMessage(pick.tool.name, to))
        focusSlot(to)
      },
      onFailed: (message) => status(pick.rank, { state: 'error', message, retry: () => moveSlot(pick, direction) }),
    })
  })

  const removeSlot = whenIdle((pick: RankedPick) => {
    status(pick.rank, { state: 'saving' })
    run((options) => router.patch(TOOLBOX, { operations: [{ op: 'remove_pick', category, rank: pick.rank, expected_tool: pick.tool.slug }] }, options), {
      onSaved: () => {
        status(pick.rank, null)
        setAnnouncement(`Removed ${pick.tool.name} from your ${rankLabel(pick.rank)} pick`)
        focusSlot(pick.rank)
      },
      onFailed: (message) => status(pick.rank, { state: 'error', message, retry: () => removeSlot(pick) }),
    })
  })

  // `landing` is the slot the pick ends up in, for the announcement and focus.
  const confirmSuggestion = whenIdle((suggestion: Suggestion, options: ConfirmOptions, landing: number) => {
    setSuggestionError(null)
    run((visit) => router.post(`${TOOLBOX}/suggestions/${suggestion.id}/confirm`, options, visit), {
      onSaved: () => {
        setAnnouncement(`Confirmed ${suggestion.tool.name} as your ${rankLabel(landing)} pick`)
        focusSlot(landing)
      },
      onFailed: setSuggestionError,
    })
  })

  const dismissSuggestion = whenIdle((suggestion: Suggestion) => {
    setSuggestionError(null)
    run((visit) => router.delete(`${TOOLBOX}/suggestions/${suggestion.id}`, visit), {
      onSaved: () => {
        setAnnouncement(`Removed the suggestion of ${suggestion.tool.name}`)
        if (suggestion.target_rank) focusSlot(suggestion.target_rank)
        else setFocus({ id: 'kind-heading' })
      },
      onFailed: setSuggestionError,
    })
  })

  return { busy, drafts, statuses, suggestionError, announcement, saveSlot, moveSlot, removeSlot, confirmSuggestion, dismissSuggestion }
}
