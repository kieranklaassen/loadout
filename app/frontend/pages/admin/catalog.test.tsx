import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import type { ReactNode } from 'react'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import type { AdminCatalogItem, CatalogStatus } from '../../types'
import AdminCatalog from './catalog'

const { patch } = vi.hoisted(() => ({ patch: vi.fn() }))

vi.mock('@inertiajs/react', () => ({
  Head: () => null,
  Link: ({ href, children, ...rest }: { href: string; children: ReactNode }) => (
    <a href={href} {...rest}>
      {children}
    </a>
  ),
  router: { patch, get: vi.fn(), post: vi.fn(), delete: vi.fn() },
  usePage: () => ({ props: { current_user: null, flash: {} }, url: '/admin/catalog_items' }),
}))

const base = { maker: null, family: null, created_by: null, created_at: '2026-09-01T12:00:00Z', pending: false, mark: null, status: 'approved' } as const

const cursor: AdminCatalogItem = { ...base, id: 1, slug: 'cursor', name: 'Cursor', kind: 'tool', maker: 'Anysphere', mark: 'cursor' }
const opus: AdminCatalogItem = {
  ...base,
  id: 2,
  slug: 'claude-opus-5-5',
  name: 'Claude Opus 5.5',
  kind: 'model',
  family: 'claude-opus',
  released_on: '2026-09-07',
  vibe_check_url: 'https://checks.every.to/vibe-checks/claude-opus-5-5',
}
const hedra: AdminCatalogItem = {
  ...base,
  id: 3,
  slug: 'hedra-studio',
  name: 'Hedra Studio',
  kind: 'tool',
  status: 'pending',
  pending: true,
  created_by: { name: 'Cy Every', handle: 'cy' },
}

const props = (overrides: Partial<Parameters<typeof AdminCatalog>[0]> = {}) => ({
  pending: [hedra],
  items: [cursor, opus, hedra],
  filters: { kind: 'all' as const, status: 'all' as const, q: '' },
  counts: { pending: 1, approved: 2, hidden: 0 } satisfies Record<CatalogStatus, number>,
  merge_targets: { tool: [{ id: 1, name: 'Cursor' }], model: [{ id: 2, name: 'Claude Opus 5.5' }] },
  ...overrides,
})

beforeEach(() => {
  patch.mockReset()
})

const row = (name: string) => screen.getByText(name, { selector: 'p' }).closest('li') as HTMLElement

describe('Admin catalog page', () => {
  it('shows who added a pending item, no usage counts, and each status', () => {
    render(<AdminCatalog {...props()} />)

    const card = screen.getByRole('heading', { name: 'Waiting for review' }).closest('section') as HTMLElement
    expect(within(card).getByText('Cy Every')).toBeInTheDocument()
    expect(within(card).getByText('Pending review')).toBeInTheDocument()
    expect(screen.queryByText(/\bpeople\b|\bperson\b/)).not.toBeInTheDocument()
    expect(within(row('Cursor')).getByText('Approved')).toBeInTheDocument()
  })

  it('shows the release date on a model row and offers launch fields only when editing a model', async () => {
    const user = userEvent.setup()
    render(<AdminCatalog {...props()} />)

    expect(within(row('Claude Opus 5.5')).getByText(/released Sep 7, 2026/)).toBeInTheDocument()

    await user.click(within(row('Claude Opus 5.5')).getByRole('button', { name: 'Edit' }))
    expect(screen.getByLabelText('Release date')).toHaveValue('2026-09-07')
    expect(screen.getByLabelText('Vibe Check link')).toHaveValue('https://checks.every.to/vibe-checks/claude-opus-5-5')

    await user.click(within(row('Claude Opus 5.5')).getByRole('button', { name: 'Close' }))
    await user.click(within(row('Cursor')).getByRole('button', { name: 'Edit' }))
    expect(screen.queryByLabelText('Release date')).not.toBeInTheDocument()
    expect(screen.queryByLabelText('Vibe Check link')).not.toBeInTheDocument()
  })

  it('saves a model with its launch fields, and a tool without them', async () => {
    const user = userEvent.setup()
    render(<AdminCatalog {...props()} />)

    await user.click(within(row('Claude Opus 5.5')).getByRole('button', { name: 'Edit' }))
    const link = screen.getByLabelText('Vibe Check link')
    await user.clear(link)
    await user.type(link, 'https://checks.every.to/vibe-checks/opus-5-5')
    await user.click(screen.getByRole('button', { name: 'Save' }))

    expect(patch).toHaveBeenCalledWith(
      '/admin/catalog_items/2?kind=model',
      { item: { name: 'Claude Opus 5.5', maker: '', released_on: '2026-09-07', vibe_check_url: 'https://checks.every.to/vibe-checks/opus-5-5' } },
      expect.objectContaining({ onError: expect.any(Function) }),
    )

    await user.click(within(row('Claude Opus 5.5')).getByRole('button', { name: 'Close' }))
    await user.click(within(row('Cursor')).getByRole('button', { name: 'Edit' }))
    await user.click(screen.getByRole('button', { name: 'Save' }))

    expect(patch).toHaveBeenLastCalledWith('/admin/catalog_items/1?kind=tool', { item: { name: 'Cursor', maker: 'Anysphere' } }, expect.anything())
  })

  it('shows the server error for a rejected link and keeps the form open', async () => {
    const user = userEvent.setup()
    patch.mockImplementation((_url, _data, options) =>
      options.onError({ vibe_check_url: 'Vibe check url must be an https link on every.to or checks.every.to' }),
    )
    render(<AdminCatalog {...props()} />)

    await user.click(within(row('Claude Opus 5.5')).getByRole('button', { name: 'Edit' }))
    await user.click(screen.getByRole('button', { name: 'Save' }))

    expect(screen.getByRole('alert')).toHaveTextContent('must be an https link on every.to or checks.every.to')
    expect(screen.getByLabelText('Vibe Check link')).toBeInTheDocument()
  })

  it('approves a pending item with its edits', async () => {
    const user = userEvent.setup()
    render(<AdminCatalog {...props()} />)

    await user.click(screen.getByRole('button', { name: 'Approve' }))

    expect(patch).toHaveBeenCalledWith(
      '/admin/catalog_items/3?kind=tool',
      { item: { name: 'Hedra Studio', maker: '', status: 'approved' } },
      expect.anything(),
    )
  })

  it('keeps Merge disabled until a target is chosen', async () => {
    const user = userEvent.setup()
    render(<AdminCatalog {...props({ merge_targets: { tool: [{ id: 1, name: 'Cursor' }], model: [] } })} />)
    const card = screen.getByRole('heading', { name: 'Waiting for review' }).closest('section') as HTMLElement

    expect(within(card).getByRole('button', { name: 'Merge' })).toBeDisabled()
    await user.selectOptions(within(card).getByLabelText('Merge Hedra Studio into'), 'Cursor')
    expect(within(card).getByRole('button', { name: 'Merge' })).toBeEnabled()
  })
})
