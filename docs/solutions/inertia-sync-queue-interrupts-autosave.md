---
title: Inertia's sync request queue aborts an in-flight save when a second visit starts
module: frontend
date: 2026-09-27
problem_type: gotcha
component: app/frontend/components/rank/use_editor_actions.ts
tags: [inertia, react, autosave, router, races]
applies_when: A page fires several Inertia writes (router.patch, post or delete) from independent controls without waiting for each response, for example per-field autosave.
---

## Problem

The Rank editor saves each slot as soon as a select changes. Change a second
select, or click Move, Remove or Confirm, before the first request returns and
the first slot stays at "Saving…" forever: no error, no Retry, and its
optimistic draft keeps overriding the server value. The write itself usually
reaches the server, so the member cannot tell whether it persisted.

Because Remove, Move and slot edits address a pick by its rank, the same overlap
also makes a double-click on Remove delete the pick that compacted into that
rank.

## Cause

`@inertiajs/core` 3.7.1 runs every non-`async` visit through one app-wide
`syncRequestStream` with `maxConcurrent: 1` and `interruptible: true`. Starting
a new sync visit calls `interruptInFlight()`, which cancels the visit in flight.
A cancelled visit fires `onCancel` and `onFinish` and never `onSuccess` or
`onError`, so a hook that only listens for those two never settles that slot.

Two details that change the fix:

- `router.reload()` forces `async: true`, so a reload (the WebMCP write reload
  in `app/frontend/lib/webmcp_provider.tsx`) does not interrupt a sync save and needs no
  change.
- The queue is shared by the whole page, so an unrelated visit (a sidebar link,
  the Add a tool form) can interrupt an editor save too.

## Solution

`useEditorActions` in `app/frontend/components/rank/use_editor_actions.ts` keeps
at most one write in flight per hook instance:

- A ref (`inFlight`) decides whether a new action may start, so two calls in the
  same tick cannot both pass; a `busy` state mirrors it for rendering.
- `run()` settles exactly once, from whichever of `onSuccess`, `onError`,
  `onNetworkError`, `onHttpException` or `onFinish` arrives first. A cancelled
  visit therefore counts as a failed request instead of leaving `busy` stuck.
- Buttons get `aria-disabled` while busy and keep their text; selects ignore
  changes but stay focusable (the `disabled` attribute would drop keyboard
  focus).

Tests: `app/frontend/components/rank/use_editor_actions.test.tsx` and the
overlap cases in `app/frontend/pages/loadout/edit.test.tsx`.

## Prevention

- For any new autosave or multi-control page, decide up front between
  `async: true` visits (they never interrupt each other, but responses can
  arrive out of order and older props can land after newer ones) and one write
  at a time. The Rank editor takes the second because its operations address
  slots by position.
- Listen for `onFinish` as the catch-all settle callback whenever the UI holds
  per-request state; `onSuccess` and `onError` alone miss cancelled visits.
- Test overlapping actions, not only the happy path: two actions in the same
  tick must send one request.
- Still open: position-only addressing. A retry after an applied-but-lost
  response, or a stale second tab, can act on the wrong pick. The fix is to send
  the acted-on tool with `remove_pick`, `move_pick` and `set_pick` and refuse a
  mismatch in `Loadouts::Slots`, as `Suggestions` already does for confirm.
