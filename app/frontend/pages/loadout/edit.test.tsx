import { act, render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import type { ReactNode } from 'react'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import WebmcpProvider from '../../lib/webmcp_provider'
import type { CatalogOption, EditorKind, TeamTop } from '../../lib/ranking'
import { claudeCodeMark, cursorMark, markItem, opusMark, rankedPick, suggestion } from '../../test/picker_fixtures'
import { installModelContext, removeModelContext } from '../../test/model_context_stub'
import type { MarkItem, Suggestion, Visibility } from '../../types'
import LoadoutEdit from './edit'

const { patch, post, del, reload, replaceProp } = vi.hoisted(() => ({
  patch: vi.fn(),
  post: vi.fn(),
  del: vi.fn(),
  reload: vi.fn(),
  replaceProp: vi.fn(),
}))

vi.mock('@inertiajs/react', () => ({
  Head: () => null,
  Link: ({ href, children, preserveScroll: _scroll, preserveState: _state, ...rest }: { href: string; children: ReactNode; preserveScroll?: boolean; preserveState?: boolean }) => (
    <a href={href} {...rest}>
      {children}
    </a>
  ),
  router: { patch, post, delete: del, reload, replaceProp, on: () => () => {} },
  usePage: () => ({ props: { current_user: null, flash: {} }, url: '/loadout/edit?kind=coding' }),
}))

const KIND_NAMES = [
  'Coding', 'Knowledge work', 'Writing', 'Research', 'Classification', 'Image', 'Video', 'Animation', 'Text to speech', 'Speech to text', 'Music',
]
const slugOf = (name: string) => name.toLowerCase().replace(/ /g, '-')

const kindOf = (name: string, overrides: Partial<EditorKind> = {}): EditorKind => ({
  category: { slug: slugOf(name), name, blurb: `${name} blurb.` },
  picks: [],
  suggestions: [],
  to_confirm: overrides.suggestions?.length ?? 0,
  ...overrides,
})

const option = (item: MarkItem, suggested_for: string[] = []): CatalogOption => ({ ...item, suggested_for })
const runway = markItem('runway', 'Runway')
const codex = markItem('codex', 'Codex')
const gpt = markItem('gpt-6-astra', 'GPT-6 Astra', 'model')

const catalog = {
  tools: [option(cursorMark, ['coding']), option(claudeCodeMark, ['coding']), option(codex, ['coding']), option(runway, ['video'])],
  models: [option(opusMark, ['coding']), option(gpt, [])],
}
const enums = { context: ['200k', '1m'] as const, effort: ['low', 'medium', 'high'] as const }

const standing = (item: MarkItem, n: number) => ({ item, count: { n, of: 6 }, yours_rank: null })
const modelStanding = (item: MarkItem, n: number, launched: boolean) => ({ ...standing(item, n), launched })
const teamTop: TeamTop = {
  coding: {
    tools: [standing(claudeCodeMark, 5), standing(cursorMark, 2), standing(codex, 1)],
    models: [modelStanding(opusMark, 4, false), modelStanding(gpt, 2, true)],
  },
}

type Props = Parameters<typeof LoadoutEdit>[0]

// Claude Code 1st with Opus, Cursor 2nd, nothing 3rd: the state most tests start from.
const twoPicks = () => [rankedPick({ rank: 1, tool: claudeCodeMark, model: opusMark, context: '1m', effort: 'high' }), rankedPick({ rank: 2, tool: cursorMark, model: null })]

const props = (overrides: Partial<Props> = {}, coding: Partial<EditorKind> = {}): Props => ({
  kinds: KIND_NAMES.map((name) => (name === 'Coding' ? kindOf(name, { picks: twoPicks(), ...coding }) : kindOf(name))),
  catalog,
  enums: { context: [...enums.context], effort: [...enums.effort] },
  selected_kind: 'coding',
  visibility: 'only_me' as Visibility,
  team_top: teamTop,
  ...overrides,
})

const saved = { props: { flash: {} } }
const succeed = (_url: string, _data: unknown, options: { onSuccess?: (page: unknown) => void }) => options.onSuccess?.(saved)

const slot = (name: string) => screen.getByRole('group', { name })
const field = (name: string, label: string) => within(slot(name)).getByLabelText(label, { exact: false }) as HTMLSelectElement
const options = (select: HTMLSelectElement) => Array.from(select.options).map((entry) => entry.value)

beforeEach(() => {
  ;[patch, post, del, reload, replaceProp].forEach((mock) => mock.mockReset())
  patch.mockImplementation(succeed)
  post.mockImplementation(succeed)
  del.mockImplementation((url: string, options: { onSuccess?: (page: unknown) => void }) => succeed(url, null, options))
})

describe('Rank editor layout', () => {
  it('lists the eleven kinds with how far along each is, and opens the selected one', () => {
    const state = props({}, { suggestions: [suggestion({ id: 1, target_rank: 3 })] })
    state.kinds[2] = kindOf('Writing', { picks: [rankedPick({ rank: 1 }), rankedPick({ rank: 2, tool: cursorMark }), rankedPick({ rank: 3, tool: runway })] })
    render(<LoadoutEdit {...state} />)

    const nav = screen.getByRole('navigation', { name: 'Kinds of work' })
    expect(within(nav).getAllByRole('link')).toHaveLength(11)
    expect(within(nav).getByRole('link', { name: /^Coding\s*3 of 3 · 1 to confirm$/ })).toHaveAttribute('aria-current', 'page')
    expect(within(nav).getByRole('link', { name: /Writing\s*3 of 3$/ })).toHaveAttribute('href', '/loadout/edit?kind=writing')
    expect(within(nav).getByRole('link', { name: /Music\s*Not started/ })).not.toHaveAttribute('aria-current')
    expect(screen.getByRole('heading', { level: 2, name: 'Coding' })).toBeInTheDocument()
    expect(screen.getByText(/of 11 kinds started/)).toBeInTheDocument()
  })

  it('says who can see the page, in the shared words, and links to change it', () => {
    const { rerender } = render(<LoadoutEdit {...props({ visibility: 'only_me' })} />)
    expect(screen.getByText(/Only you can see this\./)).toBeInTheDocument()
    expect(screen.getByRole('link', { name: 'Change who can see it' })).toHaveAttribute('href', '/settings')

    rerender(<LoadoutEdit {...props({ visibility: 'team' })} />)
    expect(screen.getByText(/People on the Every team can see this\./)).toBeInTheDocument()
    rerender(<LoadoutEdit {...props({ visibility: 'link' })} />)
    expect(screen.getByText(/Anyone with the link can see this and find you in search\./)).toBeInTheDocument()
  })

  it('tells the member changes save as they go and that suggestions stay private, and offers the agent card with WebMCP', () => {
    render(<LoadoutEdit {...props()} />)

    expect(screen.getByText(/Changes save as you go\. Suggested picks stay private until you confirm\./)).toBeInTheDocument()
    expect(screen.getByRole('link', { name: /set up an agent/i })).toHaveAttribute('href', '/agents')
    expect(screen.getByText(/WebMCP/)).toBeInTheDocument()
  })
})

describe('slots and their selects', () => {
  it('labels TOOL, MODEL, CONTEXT and EFFORT with real labels on real selects, in every slot', () => {
    render(<LoadoutEdit {...props()} />)

    for (const name of ['1st pick', '2nd pick', 'Add your 3rd pick']) {
      for (const label of ['Tool', 'Model', 'Context', 'Effort']) {
        expect(field(name, label).tagName).toBe('SELECT')
      }
    }
    expect(within(slot('Add your 3rd pick')).getByLabelText('Model (optional)')).toBeInTheDocument()
  })

  it('offers exactly the shared context and effort values, and Not set', () => {
    render(<LoadoutEdit {...props()} />)

    expect(options(field('1st pick', 'Context'))).toEqual(['', '200k', '1m'])
    expect(options(field('1st pick', 'Effort'))).toEqual(['', 'low', 'medium', 'high'])
  })

  it('groups tools as Suggested for the kind, then All tools, and models the same way', () => {
    render(<LoadoutEdit {...props()} />)

    const tool = field('1st pick', 'Tool')
    const groups = Array.from(tool.querySelectorAll('optgroup')).map((group) => [group.label, Array.from(group.querySelectorAll('option')).map((entry) => entry.textContent)])
    expect(groups).toEqual([
      ['Suggested for Coding', ['Cursor', 'Claude Code', 'Codex']],
      ['All tools', ['Runway']],
    ])
    const model = Array.from(field('1st pick', 'Model').querySelectorAll('optgroup')).map((group) => group.label)
    expect(model).toEqual(['Suggested for Coding', 'All models'])
  })

  it('shows a saved value and offers Not set on model, context and effort', () => {
    render(<LoadoutEdit {...props()} />)

    expect(field('1st pick', 'Tool')).toHaveValue('claude-code')
    expect(field('1st pick', 'Model')).toHaveValue('claude-opus-5-5')
    expect(field('1st pick', 'Context')).toHaveValue('1m')
    expect(field('1st pick', 'Effort')).toHaveValue('high')
    expect(options(field('1st pick', 'Model'))[0]).toBe('')
  })

  it('leaves only TOOL on in an empty slot until a tool is saved', () => {
    render(<LoadoutEdit {...props()} />)

    expect(field('Add your 3rd pick', 'Tool')).toBeEnabled()
    for (const label of ['Model', 'Context', 'Effort']) expect(field('Add your 3rd pick', label)).toBeDisabled()
    for (const label of ['Model', 'Context', 'Effort']) expect(field('1st pick', label)).toBeEnabled()
  })

  it('disables a tool another slot of the kind already uses, but not the slot’s own', () => {
    render(<LoadoutEdit {...props()} />)

    const second = field('2nd pick', 'Tool')
    expect(within(second).getByRole('option', { name: 'Claude Code' })).toBeDisabled()
    expect(within(second).getByRole('option', { name: 'Cursor' })).toBeEnabled()
    expect(within(field('Add your 3rd pick', 'Tool')).getByRole('option', { name: 'Claude Code' })).toBeDisabled()
    expect(within(field('Add your 3rd pick', 'Tool')).getByRole('option', { name: 'Codex' })).toBeEnabled()
  })

  it('keeps a saved tool the catalog no longer offers', () => {
    const hidden = markItem('old-thing', 'Old Thing')
    render(<LoadoutEdit {...props({}, { picks: [rankedPick({ rank: 1, tool: hidden, model: null })] })} />)

    expect(field('1st pick', 'Tool')).toHaveValue('old-thing')
  })
})

describe('autosave', () => {
  it('choosing a tool in an empty slot sends one operation with its rank', async () => {
    const user = userEvent.setup()
    render(<LoadoutEdit {...props()} />)

    await user.selectOptions(field('Add your 3rd pick', 'Tool'), 'codex')

    expect(patch).toHaveBeenCalledTimes(1)
    expect(patch).toHaveBeenCalledWith(
      '/loadout',
      { operations: [{ op: 'set_pick', category: 'coding', rank: 3, tool: 'codex' }] },
      expect.objectContaining({ preserveScroll: true, preserveState: true }),
    )
  })

  it('a model change sends only that slot’s operation with only the model', async () => {
    const user = userEvent.setup()
    render(<LoadoutEdit {...props()} />)

    await user.selectOptions(field('1st pick', 'Model'), 'gpt-6-astra')

    expect(patch).toHaveBeenCalledTimes(1)
    expect(patch.mock.calls[0]![1]).toEqual({ operations: [{ op: 'set_pick', category: 'coding', rank: 1, model: 'gpt-6-astra' }] })
  })

  it('Not set sends null for the model, the context and the effort', async () => {
    const user = userEvent.setup()
    render(<LoadoutEdit {...props()} />)

    await user.selectOptions(field('1st pick', 'Model'), '')
    await user.selectOptions(field('1st pick', 'Context'), '')
    await user.selectOptions(field('1st pick', 'Effort'), '')

    expect(patch.mock.calls.map((call) => call[1].operations)).toEqual([
      [{ op: 'set_pick', category: 'coding', rank: 1, model: null }],
      [{ op: 'set_pick', category: 'coding', rank: 1, context: null }],
      [{ op: 'set_pick', category: 'coding', rank: 1, effort: null }],
    ])
  })

  it('says Saving… while the request is out and Saved once it lands', async () => {
    const user = userEvent.setup()
    let landed: ((page: unknown) => void) | undefined
    patch.mockImplementation((_url, _data, options) => {
      landed = options.onSuccess
    })
    render(<LoadoutEdit {...props()} />)

    await user.selectOptions(field('1st pick', 'Effort'), 'low')
    const status = within(slot('1st pick')).getByRole('status')
    expect(status).toHaveTextContent('Saving…')
    expect(field('1st pick', 'Effort')).toHaveValue('low')

    act(() => landed?.(saved))
    expect(status).toHaveTextContent('Saved')
  })

  it('shows an alert with Retry when the save is refused, reverts the select, and retries the same change', async () => {
    const user = userEvent.setup()
    patch.mockImplementationOnce((_url, _data, options) => options.onSuccess({ props: { flash: { alert: 'That slot changed while you were saving.' } } }))
    render(<LoadoutEdit {...props()} />)

    await user.selectOptions(field('1st pick', 'Effort'), 'low')

    const alert = within(slot('1st pick')).getByRole('alert')
    expect(alert).toHaveTextContent('That slot changed while you were saving.')
    expect(field('1st pick', 'Effort')).toHaveValue('high')
    expect(replaceProp).toHaveBeenCalledWith('flash', {})

    await user.click(within(alert).getByRole('button', { name: 'Retry' }))

    expect(patch).toHaveBeenCalledTimes(2)
    expect(patch.mock.calls[1]![1]).toEqual(patch.mock.calls[0]![1])
    expect(within(slot('1st pick')).queryByRole('alert')).not.toBeInTheDocument()
    expect(within(slot('1st pick')).getByRole('status')).toHaveTextContent('Saved')
  })

  it('treats a request that never got an answer as a failed save', async () => {
    const user = userEvent.setup()
    patch.mockImplementationOnce((_url, _data, options) => options.onNetworkError(new Error('offline')))
    render(<LoadoutEdit {...props()} />)

    await user.selectOptions(field('1st pick', 'Effort'), 'low')

    expect(within(slot('1st pick')).getByRole('alert')).toHaveTextContent(/did not save/i)
    expect(field('1st pick', 'Effort')).toHaveValue('high')
  })

  it('marks a pick on a pending tool or model as pending review', () => {
    const pending = { ...markItem('zed', 'Zed'), pending: true }
    render(<LoadoutEdit {...props({}, { picks: [rankedPick({ rank: 1, tool: pending, model: null })] })} />)

    expect(within(slot('1st pick')).getByText('Pending review')).toBeInTheDocument()
  })
})

describe('move and remove', () => {
  it('names each action for its pick and disables the ends without hiding them', () => {
    render(<LoadoutEdit {...props()} />)

    const first = within(slot('1st pick'))
    expect(first.getByRole('button', { name: 'Move Claude Code up' })).toHaveAttribute('aria-disabled', 'true')
    expect(first.getByRole('button', { name: 'Move Claude Code down' })).not.toHaveAttribute('aria-disabled')
    expect(first.getByRole('button', { name: 'Remove Claude Code' })).toBeInTheDocument()
    const second = within(slot('2nd pick'))
    expect(second.getByRole('button', { name: 'Move Cursor down' })).toHaveAttribute('aria-disabled', 'true')
    expect(second.getByText('Move down')).toBeVisible()
    expect(within(slot('Add your 3rd pick')).queryByRole('button', { name: /move|remove/i })).not.toBeInTheDocument()
  })

  it('does nothing when a disabled move is pressed', async () => {
    const user = userEvent.setup()
    render(<LoadoutEdit {...props()} />)

    await user.click(within(slot('1st pick')).getByRole('button', { name: 'Move Claude Code up' }))
    await user.click(within(slot('2nd pick')).getByRole('button', { name: 'Move Cursor down' }))

    expect(patch).not.toHaveBeenCalled()
  })

  it('Move up is one swap operation; the live region says the new rank and focus lands on that slot', async () => {
    const user = userEvent.setup()
    render(<LoadoutEdit {...props()} />)

    await user.click(within(slot('2nd pick')).getByRole('button', { name: 'Move Cursor up' }))

    expect(patch).toHaveBeenCalledTimes(1)
    expect(patch.mock.calls[0]![1]).toEqual({ operations: [{ op: 'move_pick', category: 'coding', rank: 2, direction: 'up' }] })
    expect(screen.getByText('Cursor is now 1st')).toBeInTheDocument()
    expect(document.activeElement).toBe(screen.getByRole('heading', { name: '1st pick' }))
  })

  it('reflects the new order once the page sends it back', async () => {
    const user = userEvent.setup()
    const { rerender } = render(<LoadoutEdit {...props()} />)
    await user.click(within(slot('2nd pick')).getByRole('button', { name: 'Move Cursor up' }))

    const swapped = [rankedPick({ rank: 1, tool: cursorMark, model: null }), rankedPick({ rank: 2, tool: claudeCodeMark, model: opusMark, context: '1m', effort: 'high' })]
    rerender(<LoadoutEdit {...props({}, { picks: swapped })} />)

    expect(field('1st pick', 'Tool')).toHaveValue('cursor')
    expect(field('2nd pick', 'Tool')).toHaveValue('claude-code')
    expect(within(slot('2nd pick')).getByRole('button', { name: 'Move Claude Code down' })).toHaveAttribute('aria-disabled', 'true')
  })

  it('Remove sends remove_pick, announces it and moves focus to that slot', async () => {
    const user = userEvent.setup()
    render(<LoadoutEdit {...props()} />)

    await user.click(within(slot('1st pick')).getByRole('button', { name: 'Remove Claude Code' }))

    expect(patch.mock.calls[0]![1]).toEqual({ operations: [{ op: 'remove_pick', category: 'coding', rank: 1 }] })
    expect(screen.getByText('Removed Claude Code from your 1st pick')).toBeInTheDocument()
    expect(document.activeElement).toBe(screen.getByRole('heading', { name: '1st pick' }))
  })

  it('shows a refused move in the slot with Retry', async () => {
    const user = userEvent.setup()
    patch.mockImplementationOnce((_url, _data, options) => options.onSuccess({ props: { flash: { alert: 'Nothing is ranked 3rd for coding.' } } }))
    render(<LoadoutEdit {...props()} />)

    await user.click(within(slot('2nd pick')).getByRole('button', { name: 'Move Cursor up' }))

    expect(within(slot('2nd pick')).getByRole('alert')).toHaveTextContent('Nothing is ranked 3rd for coding.')
    expect(screen.queryByText('Cursor is now 1st')).not.toBeInTheDocument()
  })
})

// Requests the test answers by hand, the way a slow network would. Inertia ends every one with onFinish, after its outcome.
type Held = { onSuccess: (page: unknown) => void; onError: (errors: Record<string, string>) => void; onFinish: () => void }
const hold = (...mocks: (typeof patch)[]) => {
  const held: Held[] = []
  mocks.forEach((mock) => mock.mockImplementation((...args: unknown[]) => held.push(args[args.length - 1] as Held)))
  return held
}
const land = (request: Held) =>
  act(() => {
    request.onSuccess(saved)
    request.onFinish()
  })
const refuse = (request: Held) =>
  act(() => {
    request.onError({ base: 'That did not save.' })
    request.onFinish()
  })

describe('one request at a time', () => {
  const state = () => props({}, { suggestions: [suggestion({ id: 7, tool: runway, target_rank: 3 })] })
  const team = () => within(screen.getByRole('region', { name: 'What the team uses for Coding' }))
  // Every control that starts a request, except the four selects.
  const buttons = () => [
    within(slot('1st pick')).getByRole('button', { name: 'Move Claude Code down' }),
    within(slot('1st pick')).getByRole('button', { name: 'Remove Claude Code' }),
    within(slot('2nd pick')).getByRole('button', { name: 'Move Cursor up' }),
    within(slot('2nd pick')).getByRole('button', { name: 'Remove Cursor' }),
    screen.getByRole('button', { name: 'Confirm Runway' }),
    screen.getByRole('button', { name: 'Remove suggested Runway' }),
    team().getByRole('button', { name: 'Use as 3rd pick: Codex' }),
    team().getByRole('button', { name: 'Use in 2nd pick: GPT-6 Astra' }),
  ]

  it('ignores an edit in another slot while a save is out, then takes it once the save has landed', async () => {
    const user = userEvent.setup()
    const held = hold(patch)
    render(<LoadoutEdit {...props()} />)

    await user.selectOptions(field('1st pick', 'Effort'), 'low')
    await user.selectOptions(field('2nd pick', 'Model'), 'gpt-6-astra')

    expect(patch).toHaveBeenCalledTimes(1)
    expect(field('2nd pick', 'Model')).toHaveValue('')
    expect(within(slot('2nd pick')).getByRole('status')).not.toHaveTextContent('Saving')

    land(held[0]!)
    expect(within(slot('1st pick')).getByRole('status')).toHaveTextContent('Saved')

    await user.selectOptions(field('2nd pick', 'Model'), 'gpt-6-astra')
    expect(patch).toHaveBeenCalledTimes(2)
    expect(patch.mock.calls[1]![1]).toEqual({ operations: [{ op: 'set_pick', category: 'coding', rank: 2, model: 'gpt-6-astra' }] })
  })

  it('removes one pick when Remove is double-clicked', async () => {
    const user = userEvent.setup()
    const held = hold(patch)
    render(<LoadoutEdit {...props()} />)

    await user.dblClick(within(slot('1st pick')).getByRole('button', { name: 'Remove Claude Code' }))

    expect(patch).toHaveBeenCalledTimes(1)
    expect(patch.mock.calls[0]![1]).toEqual({ operations: [{ op: 'remove_pick', category: 'coding', rank: 1 }] })
    land(held[0]!)
    expect(screen.getByText('Removed Claude Code from your 1st pick')).toBeInTheDocument()
  })

  it('swaps a pair once when Move up is double-clicked', async () => {
    const user = userEvent.setup()
    hold(patch)
    render(<LoadoutEdit {...props()} />)

    await user.dblClick(within(slot('2nd pick')).getByRole('button', { name: 'Move Cursor up' }))

    expect(patch).toHaveBeenCalledTimes(1)
  })

  describe.each([
    ['lands', land],
    ['is refused', refuse],
  ])('while a request %s', (_name, settle) => {
    it('marks Move, Remove, Confirm and Use aria-disabled, keeps their text, and acts on none of them', async () => {
      const user = userEvent.setup()
      const held = hold(patch, post, del)
      render(<LoadoutEdit {...state()} />)
      const before = buttons().map((button) => button.textContent)
      buttons().forEach((button) => expect(button).not.toHaveAttribute('aria-disabled'))

      await user.selectOptions(field('1st pick', 'Effort'), 'low')

      buttons().forEach((button) => expect(button).toHaveAttribute('aria-disabled', 'true'))
      expect(buttons().map((button) => button.textContent)).toEqual(before)
      for (const button of buttons()) await user.click(button)
      expect(held).toHaveLength(1)
      expect(post).not.toHaveBeenCalled()
      expect(del).not.toHaveBeenCalled()

      settle(held[0]!)

      buttons().forEach((button) => expect(button).not.toHaveAttribute('aria-disabled'))
    })
  })

  it('keeps the selects focusable but ignores a change in any of them while a request is out', async () => {
    const user = userEvent.setup()
    const held = hold(patch)
    render(<LoadoutEdit {...props()} />)
    await user.click(within(slot('1st pick')).getByRole('button', { name: 'Move Claude Code down' }))

    for (const [name, label, value] of [['1st pick', 'Tool', 'codex'], ['1st pick', 'Model', 'gpt-6-astra'], ['2nd pick', 'Context', '200k'], ['2nd pick', 'Effort', 'low']]) {
      const select = field(name!, label!)
      const shown = select.value
      select.focus()
      await user.selectOptions(select, value!)

      expect(select).not.toBeDisabled()
      expect(select).toHaveAttribute('aria-disabled', 'true')
      expect(select).toHaveValue(shown)
      expect(document.activeElement).toBe(select)
    }
    expect(patch).toHaveBeenCalledTimes(1)

    land(held[0]!)
    expect(field('1st pick', 'Tool')).not.toHaveAttribute('aria-disabled')
  })

  it('frees the panel after a refused save, and Retry sends the same change once nothing else is out', async () => {
    const user = userEvent.setup()
    patch.mockImplementationOnce((_url, _data, options) => {
      options.onNetworkError(new Error('offline'))
      options.onFinish()
    })
    render(<LoadoutEdit {...props()} />)
    await user.selectOptions(field('1st pick', 'Effort'), 'low')
    const alert = within(slot('1st pick')).getByRole('alert')
    expect(within(slot('1st pick')).getByRole('button', { name: 'Remove Claude Code' })).not.toHaveAttribute('aria-disabled')

    const held = hold(patch)
    await user.click(within(slot('2nd pick')).getByRole('button', { name: 'Remove Cursor' }))
    const retry = within(alert).getByRole('button', { name: 'Retry' })
    expect(retry).toHaveAttribute('aria-disabled', 'true')
    await user.click(retry)
    expect(patch).toHaveBeenCalledTimes(2)

    land(held[0]!)
    expect(within(alert).getByRole('button', { name: 'Retry' })).not.toHaveAttribute('aria-disabled')
    await user.click(within(alert).getByRole('button', { name: 'Retry' }))
    expect(patch).toHaveBeenCalledTimes(3)
    expect(patch.mock.calls[2]![1]).toEqual({ operations: [{ op: 'set_pick', category: 'coding', rank: 1, effort: 'low' }] })
  })

  it('does not leave a slot at Saving… when another visit cancels its request', async () => {
    const user = userEvent.setup()
    const held = hold(patch)
    render(<LoadoutEdit {...props()} />)

    await user.selectOptions(field('1st pick', 'Effort'), 'low')
    act(() => held[0]!.onFinish())

    expect(within(slot('1st pick')).getByRole('alert')).toHaveTextContent(/did not save/i)
    expect(field('1st pick', 'Effort')).toHaveValue('high')
    expect(within(slot('1st pick')).getByRole('button', { name: 'Remove Claude Code' })).not.toHaveAttribute('aria-disabled')
  })
})

describe('suggestions', () => {
  it('shows a suggestion in the empty slot it would land in, with Confirm and Remove that name it', () => {
    const state = props({}, { suggestions: [suggestion({ id: 7, tool: runway, target_rank: 3, suggested_by: 'Claude' })] })
    render(<LoadoutEdit {...state} />)

    const box = within(slot('3rd pick'))
    expect(box.getByText('Suggested by Claude')).toBeInTheDocument()
    expect(box.getByRole('button', { name: 'Confirm Runway' })).toBeInTheDocument()
    expect(box.getByRole('button', { name: 'Remove suggested Runway' })).toBeInTheDocument()
    expect(box.queryByLabelText('Tool')).not.toBeInTheDocument()
  })

  it('Confirm posts the endpoint with the slot it was shown in', async () => {
    const user = userEvent.setup()
    render(<LoadoutEdit {...props({}, { suggestions: [suggestion({ id: 7, tool: runway, target_rank: 3 })] })} />)

    await user.click(screen.getByRole('button', { name: 'Confirm Runway' }))

    expect(post).toHaveBeenCalledWith('/loadout/suggestions/7/confirm', { rank: 3 }, expect.objectContaining({ preserveScroll: true }))
    expect(screen.getByText('Confirmed Runway as your 3rd pick')).toBeInTheDocument()
    expect(document.activeElement).toBe(screen.getByRole('heading', { name: '3rd pick' }))
  })

  it('Remove dismisses it', async () => {
    const user = userEvent.setup()
    render(<LoadoutEdit {...props({}, { suggestions: [suggestion({ id: 7, tool: runway, target_rank: 3 })] })} />)

    await user.click(screen.getByRole('button', { name: 'Remove suggested Runway' }))

    expect(del).toHaveBeenCalledWith('/loadout/suggestions/7', expect.objectContaining({ preserveScroll: true }))
    expect(post).not.toHaveBeenCalled()
  })

  it('stacks two suggestions for one slot, each with its own Confirm and Remove', () => {
    const stacked = [suggestion({ id: 1, tool: runway, target_rank: 3, suggested_by: 'Claude' }), suggestion({ id: 2, tool: codex, target_rank: 3, suggested_by: 'Cursor agent' })]
    render(<LoadoutEdit {...props({}, { suggestions: stacked })} />)

    const box = within(slot('3rd pick'))
    expect(box.getAllByRole('button', { name: /^Confirm / })).toHaveLength(2)
    expect(box.getByText('Suggested by Cursor agent')).toBeInTheDocument()
    expect(box.getByRole('button', { name: 'Remove suggested Codex' })).toBeInTheDocument()
  })

  it('renders a suggestion that changes a pick inside that slot, old beside new', () => {
    const change = suggestion({ id: 4, tool: cursorMark, model: opusMark, effort: 'low', target_rank: 2, replaces: { rank: 2, tool: cursorMark, model: null } })
    render(<LoadoutEdit {...props({}, { suggestions: [change] })} />)

    const box = within(slot('2nd pick'))
    expect(box.getByText('Suggested change by Claude')).toBeInTheDocument()
    expect(box.getByText('Now')).toBeInTheDocument()
    expect(box.getByText('Suggested')).toBeInTheDocument()
    expect(box.getByText('low effort')).toBeInTheDocument()
    expect(box.getByLabelText('Tool')).toHaveValue('cursor')
  })

  it('confirms a change with its slot', async () => {
    const user = userEvent.setup()
    const change = suggestion({ id: 4, tool: cursorMark, model: opusMark, target_rank: 2, replaces: { rank: 2, tool: cursorMark, model: null } })
    render(<LoadoutEdit {...props({}, { suggestions: [change] })} />)

    await user.click(screen.getByRole('button', { name: 'Confirm Cursor' }))

    expect(post).toHaveBeenCalledWith('/loadout/suggestions/4/confirm', { rank: 2 }, expect.anything())
  })

  it('counts progress up to 3 while to-confirm counts every open suggestion', () => {
    const three = [1, 2, 3].map((rank) => rankedPick({ rank, tool: markItem(`tool-${rank}`, `Tool ${rank}`), model: null }))
    const many: Suggestion[] = [1, 2, 3].map((id) => suggestion({ id, tool: markItem(`s-${id}`, `Suggested ${id}`), target_rank: id === 3 ? null : id, replaces: null }))
    render(<LoadoutEdit {...props({}, { picks: three, suggestions: many })} />)

    expect(within(screen.getByRole('navigation', { name: 'Kinds of work' })).getByRole('link', { name: /Coding\s*3 of 3 · 3 to confirm/ })).toBeInTheDocument()
  })

  describe('on a full kind', () => {
    const full = () => [1, 2, 3].map((rank) => rankedPick({ rank, tool: markItem(`tool-${rank}`, `Tool ${rank}`), model: rank === 2 ? opusMark : null }))
    const pending = suggestion({ id: 9, tool: runway, target_rank: null })

    it('asks which pick to replace, with focus in the group, and Cancel returns focus to Confirm', async () => {
      const user = userEvent.setup()
      render(<LoadoutEdit {...props({}, { picks: full(), suggestions: [pending] })} />)

      const confirm = screen.getByRole('button', { name: 'Confirm Runway' })
      await user.click(confirm)

      const group = screen.getByRole('group', { name: 'Replace which pick?' })
      expect(within(group).getAllByRole('radio')).toHaveLength(3)
      expect(document.activeElement).toBe(within(group).getAllByRole('radio')[0])
      expect(post).not.toHaveBeenCalled()

      await user.click(within(group).getByRole('button', { name: 'Cancel' }))
      expect(screen.queryByRole('group', { name: 'Replace which pick?' })).not.toBeInTheDocument()
      expect(document.activeElement).toBe(confirm)
    })

    it('replaces the chosen pick, sending the pick it was shown', async () => {
      const user = userEvent.setup()
      render(<LoadoutEdit {...props({}, { picks: full(), suggestions: [pending] })} />)

      await user.click(screen.getByRole('button', { name: 'Confirm Runway' }))
      const group = screen.getByRole('group', { name: 'Replace which pick?' })
      expect(within(group).getByRole('button', { name: 'Replace' })).toBeDisabled()
      await user.click(within(group).getByRole('radio', { name: /2nd.*Tool 2.*Claude Opus 5\.5/ }))
      await user.click(within(group).getByRole('button', { name: 'Replace' }))

      expect(post).toHaveBeenCalledWith(
        '/loadout/suggestions/9/confirm',
        { rank: 2, expected: { tool: 'tool-2', model: 'claude-opus-5-5' } },
        expect.anything(),
      )
    })

    it('shows a stale answer where the suggestion is, and starts the choice over', async () => {
      const user = userEvent.setup()
      post.mockImplementationOnce((_url, _data, options) => options.onSuccess({ props: { flash: { alert: 'This changed, review it.' } } }))
      render(<LoadoutEdit {...props({}, { picks: full(), suggestions: [pending] })} />)

      await user.click(screen.getByRole('button', { name: 'Confirm Runway' }))
      await user.click(screen.getByRole('radio', { name: /1st/ }))
      await user.click(screen.getByRole('button', { name: 'Replace' }))

      expect(screen.getByRole('alert')).toHaveTextContent('This changed, review it.')
      expect(replaceProp).toHaveBeenCalledWith('flash', {})
    })
  })
})

describe('the team list', () => {
  it('offers a tool the first empty slot, says where owned tools sit, and lists counts as N of M', () => {
    render(<LoadoutEdit {...props()} />)

    const team = within(screen.getByRole('region', { name: 'What the team uses for Coding' }))
    expect(team.getByText('5 of 6 use it')).toBeInTheDocument()
    expect(team.getByText('1 of 6 uses it')).toBeInTheDocument()
    expect(team.getByText('You have it 1st')).toBeInTheDocument()
    expect(team.getByText('You have it 2nd')).toBeInTheDocument()
    expect(team.getByRole('button', { name: 'Use as 3rd pick: Codex' })).toBeInTheDocument()
    expect(team.getByText('New · 2 of 6 are trying it')).toBeInTheDocument()
  })

  it('offers a model the first pick that has no model, and knows the one the member already uses', () => {
    render(<LoadoutEdit {...props()} />)

    const team = within(screen.getByRole('region', { name: 'What the team uses for Coding' }))
    expect(team.getByRole('button', { name: 'Use in 2nd pick: GPT-6 Astra' })).toBeInTheDocument()
    expect(team.getByText('You use it')).toBeInTheDocument()
  })

  it('fills the tool or the model through the same slot save', async () => {
    const user = userEvent.setup()
    render(<LoadoutEdit {...props()} />)
    const team = within(screen.getByRole('region', { name: 'What the team uses for Coding' }))

    await user.click(team.getByRole('button', { name: 'Use as 3rd pick: Codex' }))
    expect(patch.mock.calls[0]![1]).toEqual({ operations: [{ op: 'set_pick', category: 'coding', rank: 3, tool: 'codex' }] })
    expect(document.activeElement).toBe(screen.getByRole('heading', { name: 'Add your 3rd pick' }))

    await user.click(team.getByRole('button', { name: 'Use in 2nd pick: GPT-6 Astra' }))
    expect(patch.mock.calls[1]![1]).toEqual({ operations: [{ op: 'set_pick', category: 'coding', rank: 2, model: 'gpt-6-astra' }] })
  })

  it('hides every button on a full kind', () => {
    const three = [1, 2, 3].map((rank, index) => rankedPick({ rank, tool: [claudeCodeMark, cursorMark, runway][index]!, model: null }))
    render(<LoadoutEdit {...props({}, { picks: three })} />)

    const team = within(screen.getByRole('region', { name: 'What the team uses for Coding' }))
    expect(team.queryByRole('button')).not.toBeInTheDocument()
    expect(team.getByText('You have it 1st')).toBeInTheDocument()
  })

  it('shows no model button when no pick is waiting for one', () => {
    const modelled = [rankedPick({ rank: 1, model: opusMark })]
    render(<LoadoutEdit {...props({}, { picks: modelled })} />)

    const team = within(screen.getByRole('region', { name: 'What the team uses for Coding' }))
    expect(team.queryByRole('button', { name: /GPT-6/ })).not.toBeInTheDocument()
  })

  it('says nobody has ranked the kind when the list is empty', () => {
    render(<LoadoutEdit {...props({ team_top: { coding: { tools: [], models: [] } } })} />)

    expect(screen.getByText('Nobody has ranked coding yet')).toBeInTheDocument()
    expect(screen.queryByText(/Tools the team uses/)).not.toBeInTheDocument()
  })
})

describe('Add a tool or model', () => {
  const open = (user: ReturnType<typeof userEvent.setup>) => user.click(screen.getByRole('button', { name: 'Add a tool or model' }))
  const nameField = () => screen.getByLabelText('Name')

  it('opens an inline form with a Tool/Model choice, a name, and the note that admins review', async () => {
    const user = userEvent.setup()
    render(<LoadoutEdit {...props()} />)
    expect(screen.queryByLabelText('Name')).not.toBeInTheDocument()

    await user.click(screen.getByRole('button', { name: 'Add a tool or model' }))

    expect(screen.getByRole('radio', { name: 'Tool' })).toBeChecked()
    expect(screen.getByRole('radio', { name: 'Model' })).not.toBeChecked()
    expect(document.activeElement).toBe(nameField())
    expect(screen.getByText(/admin reviews new items/i)).toBeInTheDocument()
  })

  it('posts the kind and the squished name, then closes, returns focus to the link and confirms', async () => {
    const user = userEvent.setup()
    render(<LoadoutEdit {...props()} />)
    await open(user)

    await user.click(screen.getByRole('radio', { name: 'Model' }))
    await user.type(nameField(), '  Beta   Model ')
    await user.click(screen.getByRole('button', { name: 'Add' }))

    expect(post).toHaveBeenCalledWith('/loadout/catalog_items', { kind: 'model', name: 'Beta Model' }, expect.objectContaining({ preserveScroll: true }))
    expect(screen.queryByLabelText('Name')).not.toBeInTheDocument()
    expect(document.activeElement).toBe(screen.getByRole('button', { name: 'Add a tool or model' }))
    expect(screen.getByText(/Added Beta Model/)).toBeInTheDocument()
  })

  it('adds the new item to the lists as pending without selecting it anywhere', () => {
    const zed = { ...option({ ...markItem('zed', 'Zed'), pending: true }, []), pending: true }
    const state = props({ catalog: { ...catalog, tools: [...catalog.tools, zed] } })
    render(<LoadoutEdit {...state} />)

    const third = field('Add your 3rd pick', 'Tool')
    expect(within(third).getByRole('option', { name: 'Zed (pending review)' })).toBeInTheDocument()
    expect(third).toHaveValue('')
    expect(field('1st pick', 'Tool')).toHaveValue('claude-code')
  })

  it('says Already in the list for an exact catalog match and does not post', async () => {
    const user = userEvent.setup()
    render(<LoadoutEdit {...props()} />)
    await open(user)

    await user.type(nameField(), 'cursor')

    expect(screen.getByText('Already in the list')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Add' })).toBeDisabled()
    await user.click(screen.getByRole('radio', { name: 'Model' }))
    expect(screen.queryByText('Already in the list')).not.toBeInTheDocument()
  })

  it('needs 2 to 60 characters', async () => {
    const user = userEvent.setup()
    render(<LoadoutEdit {...props()} />)
    await open(user)

    await user.type(nameField(), 'Z')
    await user.click(screen.getByRole('button', { name: 'Add' }))
    expect(screen.getByRole('alert')).toHaveTextContent('Use 2 to 60 characters.')

    await user.clear(nameField())
    await user.type(nameField(), 'x'.repeat(61))
    await user.click(screen.getByRole('button', { name: 'Add' }))
    expect(screen.getByRole('alert')).toHaveTextContent('Use 2 to 60 characters.')
    expect(post).not.toHaveBeenCalled()
  })

  it('shows the server’s reason and keeps the form open', async () => {
    const user = userEvent.setup()
    post.mockImplementationOnce((_url, _data, options) => options.onError({ name: 'That one is with the admins already.' }))
    render(<LoadoutEdit {...props()} />)
    await open(user)

    await user.type(nameField(), 'Windsurf')
    await user.click(screen.getByRole('button', { name: 'Add' }))

    expect(screen.getByRole('alert')).toHaveTextContent('That one is with the admins already.')
    expect(nameField()).toHaveValue('Windsurf')
  })

  it('sends one request however many times it is submitted while the first is out, and takes another after', async () => {
    const user = userEvent.setup()
    const held = hold(post)
    render(<LoadoutEdit {...props()} />)
    await open(user)
    await user.type(nameField(), 'Windsurf')

    await user.dblClick(screen.getByRole('button', { name: 'Add' }))
    await user.click(nameField())
    await user.keyboard('{Enter}')

    expect(post).toHaveBeenCalledTimes(1)
    expect(screen.getByRole('button', { name: 'Add' })).toHaveAttribute('aria-disabled', 'true')

    refuse(held[0]!)

    expect(screen.getByRole('alert')).toHaveTextContent('That did not save.')
    expect(screen.getByRole('button', { name: 'Add' })).not.toHaveAttribute('aria-disabled')
    await user.click(screen.getByRole('button', { name: 'Add' }))
    expect(post).toHaveBeenCalledTimes(2)
  })
})

describe('keyboard', () => {
  it('reaches every control of a slot in reading order', async () => {
    const user = userEvent.setup()
    render(<LoadoutEdit {...props()} />)

    field('1st pick', 'Tool').focus()
    const order: string[] = []
    for (let step = 0; step < 7; step += 1) {
      order.push((document.activeElement as HTMLElement).getAttribute('aria-label') ?? (document.activeElement as HTMLSelectElement).labels?.[0]?.textContent ?? '')
      await user.tab()
    }

    expect(order).toEqual(['Tool', 'Model', 'Context', 'Effort', 'Move Claude Code up', 'Move Claude Code down', 'Remove Claude Code'])
  })
})

describe('an agent writing through WebMCP', () => {
  beforeEach(() => removeModelContext())

  it('reloads the page props after suggest_picks, so the suggestion appears; a read does not reload', async () => {
    const stub = installModelContext()
    vi.stubGlobal('fetch', vi.fn(async () => new Response(JSON.stringify({ result: { content: [{ type: 'text', text: '{}' }] } }))))
    const manifest = {
      endpoint: '/webmcp/tools',
      tools: [
        { name: 'get_my_loadout', description: 'Reads', inputSchema: { type: 'object' }, annotations: { readOnlyHint: true } },
        { name: 'suggest_picks', description: 'Suggests', inputSchema: { type: 'object' }, annotations: { readOnlyHint: false } },
      ],
    }
    const page = (state: Props) => (
      <WebmcpProvider initialManifest={manifest}>
        <LoadoutEdit {...state} />
      </WebmcpProvider>
    )
    const { rerender } = render(page(props()))
    expect(screen.queryByText(/Suggested by/)).not.toBeInTheDocument()
    reload.mockImplementation(() => rerender(page(props({}, { suggestions: [suggestion({ id: 3, tool: runway, target_rank: 3, suggested_by: 'WebMCP' })] }))))

    await act(async () => {
      await stub.invoke('get_my_loadout')
    })
    expect(reload).not.toHaveBeenCalled()

    await act(async () => {
      await stub.invoke('suggest_picks', { picks: [{ category: 'coding', tool: 'runway' }] })
    })

    expect(reload).toHaveBeenCalledTimes(1)
    expect(screen.getByText('Suggested by WebMCP')).toBeInTheDocument()
    vi.unstubAllGlobals()
    removeModelContext()
  })
})
