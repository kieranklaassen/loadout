import { act, renderHook } from '@testing-library/react'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { claudeCodeMark, cursorMark, rankedPick, suggestion } from '../../test/picker_fixtures'
import { useEditorActions } from './use_editor_actions'

const { patch, post, del, replaceProp } = vi.hoisted(() => ({ patch: vi.fn(), post: vi.fn(), del: vi.fn(), replaceProp: vi.fn() }))

vi.mock('@inertiajs/react', () => ({ router: { patch, post, delete: del, replaceProp } }))

type Request = {
  onSuccess: (page: unknown) => void
  onError: (errors: Record<string, string>) => void
  onNetworkError: (error: Error) => void
  onHttpException: (response: unknown) => void
  onFinish: () => void
}

// Requests the test answers by hand, the way a slow network would. Inertia ends every one
// with onFinish, after its outcome or, for a cancelled visit, instead of one.
let requests: Request[]
const answer = (request: Request, outcome: (request: Request) => void) =>
  act(() => {
    outcome(request)
    request.onFinish()
  })
const saved = { props: { flash: {} } }

const first = rankedPick({ rank: 1, tool: claudeCodeMark })
const second = rankedPick({ rank: 2, tool: cursorMark, model: null })

beforeEach(() => {
  requests = []
  ;[patch, post, del, replaceProp].forEach((mock) => mock.mockReset())
  const hold = (...args: unknown[]) => requests.push(args[args.length - 1] as Request)
  ;[patch, post, del].forEach((mock) => mock.mockImplementation(hold))
})

describe('useEditorActions', () => {
  it('is busy from the moment a write starts until its answer arrives', () => {
    const { result } = renderHook(() => useEditorActions('coding'))
    expect(result.current.busy).toBe(false)

    act(() => result.current.saveSlot(1, { effort: 'low' }))
    expect(result.current.busy).toBe(true)
    expect(result.current.statuses[1]).toEqual({ state: 'saving' })

    answer(requests[0]!, (request) => request.onSuccess(saved))
    expect(result.current.busy).toBe(false)
    expect(result.current.statuses[1]).toEqual({ state: 'saved' })
  })

  it('sends one request when several actions arrive before a re-render, and touches nothing for the rest', () => {
    const { result } = renderHook(() => useEditorActions('coding'))

    act(() => {
      result.current.saveSlot(1, { effort: 'low' })
      result.current.moveSlot(second, 'up')
      result.current.removeSlot(first)
      result.current.confirmSuggestion(suggestion({ id: 7 }), { rank: 3 }, 3)
      result.current.dismissSuggestion(suggestion({ id: 8 }))
    })

    expect(patch).toHaveBeenCalledTimes(1)
    expect(post).not.toHaveBeenCalled()
    expect(del).not.toHaveBeenCalled()
    expect(result.current.statuses).toEqual({ 1: { state: 'saving' } })
    expect(result.current.drafts).toEqual({ 1: { effort: 'low' } })
  })

  it('takes the next action once the request has been answered', () => {
    const { result } = renderHook(() => useEditorActions('coding'))
    act(() => result.current.removeSlot(first))
    answer(requests[0]!, (request) => request.onSuccess(saved))

    act(() => result.current.moveSlot(second, 'up'))

    expect(patch.mock.calls.map((call) => call[1].operations[0].op)).toEqual(['remove_pick', 'move_pick'])
  })

  describe('a request that fails', () => {
    const failures: [string, (request: Request) => void, string][] = [
      ['is refused with a flash alert', (request) => request.onSuccess({ props: { flash: { alert: 'That slot changed.' } } }), 'That slot changed.'],
      ['comes back with errors', (request) => request.onError({ tool: 'Pick a tool.' }), 'Pick a tool.'],
      ['never reaches the server', (request) => request.onNetworkError(new Error('offline')), 'That did not save. Try again.'],
      ['gets an error page', (request) => request.onHttpException({ status: 500 }), 'That did not save. Try again.'],
    ]

    it.each(failures)('frees the hook and offers Retry when it %s', (_name, fail, message) => {
      const { result } = renderHook(() => useEditorActions('coding'))
      act(() => result.current.removeSlot(first))

      answer(requests[0]!, fail)

      expect(result.current.busy).toBe(false)
      expect(result.current.statuses[1]).toMatchObject({ state: 'error', message })

      const error = result.current.statuses[1]
      act(() => error && error.state === 'error' && error.retry())
      expect(patch).toHaveBeenCalledTimes(2)
      expect(patch.mock.calls[1]![1]).toEqual(patch.mock.calls[0]![1])
    })
  })

  it('settles a request another visit cancelled as a failed one, so nothing stays at Saving…', () => {
    const { result } = renderHook(() => useEditorActions('coding'))
    act(() => result.current.saveSlot(1, { effort: 'low' }))

    // Another visit took the queue: the request in flight fires onCancel and onFinish, never an outcome.
    answer(requests[0]!, () => {})

    expect(result.current.busy).toBe(false)
    expect(result.current.statuses[1]).toMatchObject({ state: 'error', message: 'That did not save. Try again.' })
    expect(result.current.drafts).toEqual({})
  })

  it('does not settle a request twice when the answer is followed by its finish', () => {
    const { result } = renderHook(() => useEditorActions('coding'))
    act(() => result.current.moveSlot(second, 'up'))

    answer(requests[0]!, (request) => request.onSuccess(saved))

    expect(result.current.statuses).toEqual({ 2: null, 1: { state: 'saved' } })
    expect(result.current.announcement).toBe('Cursor is now 1st')
  })
})
