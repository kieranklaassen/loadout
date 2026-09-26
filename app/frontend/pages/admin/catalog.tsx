import type { Errors } from '@inertiajs/core'
import { Head, router } from '@inertiajs/react'
import { useEffect, useRef, useState, type FormEvent } from 'react'
import AppShell from '../../components/app_shell'
import Button from '../../components/button'
import ToolMark from '../../components/tool_mark'
import type { AdminCatalogItem, CatalogKind, CatalogStatus, MergeTarget } from '../../types'

type KindFilter = 'all' | CatalogKind
type StatusFilter = 'all' | CatalogStatus

type Props = {
  pending: AdminCatalogItem[]
  items: AdminCatalogItem[]
  filters: { kind: KindFilter; status: StatusFilter; q: string }
  counts: Record<CatalogStatus, number>
  merge_targets: Record<CatalogKind, MergeTarget[]>
}

const BASE = '/admin/catalog_items'
const itemUrl = (item: AdminCatalogItem, suffix = '') => `${BASE}/${item.id}${suffix}?kind=${item.kind}`
const visit = { preserveScroll: true, preserveState: true }

function kindLabel(kind: CatalogKind) {
  switch (kind) {
    case 'tool':
      return 'Tool'
    case 'model':
      return 'Model'
    default: {
      const unreachable: never = kind
      return unreachable
    }
  }
}

function StatusPill({ status }: { status: CatalogStatus }) {
  switch (status) {
    case 'approved':
      return <span className="rounded-full bg-every-lime/40 px-2 py-0.5 font-mono text-[0.65rem] uppercase tracking-wide text-ink">Approved</span>
    case 'pending':
      return <span className="rounded-full bg-every-coral/20 px-2 py-0.5 font-mono text-[0.65rem] uppercase tracking-wide text-ink">Pending</span>
    case 'hidden':
      return <span className="rounded-full bg-ink/5 px-2 py-0.5 font-mono text-[0.65rem] uppercase tracking-wide text-ink-muted">Hidden</span>
    default: {
      const unreachable: never = status
      return unreachable
    }
  }
}

function setStatus(item: AdminCatalogItem, status: CatalogStatus) {
  router.patch(itemUrl(item), { item: { status } }, visit)
}

const field =
  'w-full rounded-lg border-0 bg-white px-3 py-2 text-sm text-ink ring-1 ring-rule placeholder:text-ink-muted focus:ring-2 focus:ring-every-blue'

function ItemEditor({
  id,
  item,
  approve,
  onDone,
}: {
  id: string
  item: AdminCatalogItem
  approve: boolean
  onDone?: () => void
}) {
  const [values, setValues] = useState({ name: item.name, maker: item.maker ?? '', monogram: item.monogram, hue: item.hue })
  const [errors, setErrors] = useState<Errors>({})

  const submit = (event: FormEvent) => {
    event.preventDefault()
    router.patch(
      itemUrl(item),
      { item: { ...values, ...(approve ? { status: 'approved' } : {}) } },
      {
        ...visit,
        onSuccess: () => {
          setErrors({})
          onDone?.()
        },
        onError: (next) => setErrors(next),
      },
    )
  }

  return (
    <form id={id} onSubmit={submit} className="grid grid-cols-1 gap-3 sm:grid-cols-[auto_1fr_1fr_5rem] sm:items-end">
      <div className="hidden sm:block">
        <ToolMark item={values} size="lg" />
      </div>
      <label className="block">
        <span className="eyebrow">Name</span>
        <input className={`${field} mt-1`} value={values.name} onChange={(e) => setValues({ ...values, name: e.target.value })} />
      </label>
      <label className="block">
        <span className="eyebrow">Maker</span>
        <input
          className={`${field} mt-1`}
          value={values.maker}
          placeholder="Who makes it"
          onChange={(e) => setValues({ ...values, maker: e.target.value })}
        />
      </label>
      <label className="block">
        <span className="eyebrow">Mark</span>
        <input
          className={`${field} mt-1 font-mono`}
          value={values.monogram}
          maxLength={3}
          onChange={(e) => setValues({ ...values, monogram: e.target.value })}
        />
      </label>
      <label className="flex items-center gap-3 sm:col-span-3 sm:col-start-2">
        <span className="eyebrow w-10 shrink-0">Hue</span>
        <input
          type="range"
          min={0}
          max={359}
          value={values.hue}
          onChange={(e) => setValues({ ...values, hue: Number(e.target.value) })}
          className="h-1.5 flex-1 cursor-pointer appearance-none rounded-full accent-ink"
          style={{ background: 'linear-gradient(90deg, hsl(0 70% 80%), hsl(60 70% 80%), hsl(120 70% 80%), hsl(180 70% 80%), hsl(240 70% 80%), hsl(300 70% 80%), hsl(359 70% 80%))' }}
        />
        <span className="w-8 text-right font-mono text-xs tabular-nums text-ink-muted">{values.hue}</span>
        <span className="sm:hidden">
          <ToolMark item={values} size="sm" />
        </span>
      </label>
      {Object.keys(errors).length > 0 && (
        <p role="alert" className="text-sm text-every-coral sm:col-span-4">
          {Object.entries(errors)
            .map(([key, message]) => `${key} ${String(message)}`)
            .join('. ')}
        </p>
      )}
    </form>
  )
}

function MergeControl({ item, targets }: { item: AdminCatalogItem; targets: MergeTarget[] }) {
  const [target, setTarget] = useState('')
  const options = targets.filter((option) => option.id !== item.id)
  const chosen = options.find((option) => String(option.id) === target)

  const merge = () => {
    if (!chosen) return
    const people = item.people === 1 ? '1 person' : `${item.people} people`
    if (!window.confirm(`Merge ${item.name} into ${chosen.name}? ${people} will move over and ${item.name} is deleted.`)) return
    router.post(itemUrl(item, '/merge'), { target_id: chosen.id }, visit)
  }

  return (
    <div className="flex min-w-0 items-center gap-2">
      <select
        aria-label={`Merge ${item.name} into`}
        value={target}
        onChange={(e) => setTarget(e.target.value)}
        className="min-w-0 flex-1 rounded-full border-0 bg-white py-1.5 pl-3 pr-8 text-sm ring-1 ring-rule focus:ring-2 focus:ring-every-blue"
      >
        <option value="">Merge into…</option>
        {options.map((option) => (
          <option key={option.id} value={option.id}>
            {option.name}
          </option>
        ))}
      </select>
      <Button variant="secondary" disabled={!chosen} onClick={merge} className="!px-3 !py-1.5">
        Merge
      </Button>
    </div>
  )
}

function Meta({ item }: { item: AdminCatalogItem }) {
  const added = new Date(item.created_at).toLocaleDateString(undefined, { month: 'short', day: 'numeric' })
  return (
    <p className="text-xs text-ink-muted">
      {kindLabel(item.kind)}
      {item.created_by && (
        <>
          {' '}
          · added by <span className="text-ink-soft">{item.created_by.name}</span>
        </>
      )}{' '}
      · {added} · {item.people === 1 ? '1 person' : `${item.people} people`}
    </p>
  )
}

function PendingCard({ item, targets }: { item: AdminCatalogItem; targets: MergeTarget[] }) {
  return (
    <li className="card p-5">
      <div className="mb-4 flex flex-wrap items-baseline justify-between gap-2">
        <div className="min-w-0">
          <p className="truncate font-medium">
            {item.name} <span className="font-mono text-xs font-normal text-ink-muted">{item.slug}</span>
          </p>
          <Meta item={item} />
        </div>
        <StatusPill status={item.status} />
      </div>
      <ItemEditor id={`edit-${item.kind}-${item.id}`} item={item} approve />
      <div className="mt-4 flex flex-col gap-3 border-t border-rule/70 pt-4 sm:flex-row sm:items-center sm:justify-between">
        <div className="sm:w-72">
          <MergeControl item={item} targets={targets} />
        </div>
        <div className="flex items-center justify-end gap-1">
          <Button variant="ghost" onClick={() => setStatus(item, 'hidden')} className="!px-3 !py-1.5 text-ink-muted">
            Hide
          </Button>
          <Button type="submit" form={`edit-${item.kind}-${item.id}`} variant="blue" className="!py-1.5">
            Approve
          </Button>
        </div>
      </div>
    </li>
  )
}

function ItemRow({ item, targets }: { item: AdminCatalogItem; targets: MergeTarget[] }) {
  const [open, setOpen] = useState(false)
  const action = 'rounded-full px-2.5 py-1 text-xs text-ink-soft transition hover:bg-ink/5 hover:text-ink'

  const remove = () => {
    if (window.confirm(`Delete ${item.name}? Nobody uses it.`)) router.delete(itemUrl(item), visit)
  }

  return (
    <li className="py-3">
      <div className="flex items-center gap-3">
        <ToolMark item={item} size="sm" />
        <div className="min-w-0 flex-1">
          <p className="truncate text-sm font-medium">
            {item.name}
            {item.maker && <span className="font-normal text-ink-muted"> · {item.maker}</span>}
          </p>
          <p className="truncate font-mono text-[0.7rem] text-ink-muted">
            {kindLabel(item.kind).toLowerCase()} · {item.slug}
            {item.family && ` · ${item.family}`}
          </p>
        </div>
        <span className="hidden w-20 text-right font-mono text-xs tabular-nums text-ink-soft sm:block">
          {item.people} {item.people === 1 ? 'person' : 'people'}
        </span>
        <span className="w-20 text-right">
          <StatusPill status={item.status} />
        </span>
        <div className="flex shrink-0 items-center">
          <button type="button" className={action} aria-expanded={open} onClick={() => setOpen((value) => !value)}>
            {open ? 'Close' : 'Edit'}
          </button>
          {item.status === 'hidden' ? (
            <button type="button" className={action} onClick={() => setStatus(item, 'approved')}>
              Restore
            </button>
          ) : (
            <button type="button" className={action} onClick={() => setStatus(item, 'hidden')}>
              Hide
            </button>
          )}
        </div>
      </div>
      {open && (
        <div className="mt-3 rounded-2xl bg-paper-deep/70 p-4 sm:ml-10">
          <ItemEditor id={`row-${item.kind}-${item.id}`} item={item} approve={item.status === 'pending'} onDone={() => setOpen(false)} />
          <div className="mt-4 flex flex-col gap-3 border-t border-rule/70 pt-4 sm:flex-row sm:items-center sm:justify-between">
            <div className="sm:w-72">
              <MergeControl item={item} targets={targets} />
            </div>
            <div className="flex items-center justify-end gap-3">
              {item.people === 0 && (
                <button type="button" onClick={remove} className="text-xs text-every-coral hover:underline">
                  Delete
                </button>
              )}
              <Button type="submit" form={`row-${item.kind}-${item.id}`} variant={item.status === 'pending' ? 'blue' : 'primary'} className="!py-1.5">
                {item.status === 'pending' ? 'Approve' : 'Save'}
              </Button>
            </div>
          </div>
        </div>
      )}
    </li>
  )
}

function Segmented<T extends string>({
  label,
  value,
  options,
  onChange,
}: {
  label: string
  value: T
  options: { value: T; label: string }[]
  onChange: (value: T) => void
}) {
  return (
    <div role="group" aria-label={label} className="inline-flex rounded-full bg-white p-0.5 ring-1 ring-rule">
      {options.map((option) => (
        <button
          key={option.value}
          type="button"
          aria-pressed={option.value === value}
          onClick={() => onChange(option.value)}
          className={`rounded-full px-3 py-1 text-xs transition ${option.value === value ? 'bg-ink text-paper' : 'text-ink-soft hover:text-ink'}`}
        >
          {option.label}
        </button>
      ))}
    </div>
  )
}

export default function AdminCatalog({ pending, items, filters, counts, merge_targets }: Props) {
  const [query, setQuery] = useState(filters.q)
  const first = useRef(true)

  const apply = (next: Partial<Props['filters']>) => {
    const merged = { ...filters, q: query, ...next }
    router.get(
      BASE,
      {
        ...(merged.kind !== 'all' && { kind: merged.kind }),
        ...(merged.status !== 'all' && { status: merged.status }),
        ...(merged.q && { q: merged.q }),
      },
      { ...visit, replace: true },
    )
  }

  useEffect(() => {
    if (first.current) {
      first.current = false
      return
    }
    const timer = window.setTimeout(() => apply({ q: query }), 250)
    return () => window.clearTimeout(timer)
  }, [query])

  return (
    <AppShell wide>
      <Head title="Catalog review" />

      <header className="flex flex-col gap-6 border-b border-rule pb-8 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <p className="eyebrow">Admin</p>
          <h1 className="display mt-3 text-5xl">Catalog review</h1>
          <p className="mt-3 max-w-lg text-ink-soft">
            Members add tools and models while picking. Approve them, tidy the name and mark, fold duplicates into the real
            thing, or hide them from pickers.
          </p>
        </div>
        <div className="flex items-end gap-6">
          <dl className="flex gap-6">
            {(['pending', 'approved', 'hidden'] as const).map((status) => (
              <div key={status}>
                <dd className="display text-3xl tabular-nums">{counts[status]}</dd>
                <dt className="eyebrow mt-1">{status}</dt>
              </div>
            ))}
          </dl>
          <a href="/admin/flipper" className="text-sm text-ink underline decoration-rule underline-offset-4 hover:text-every-blue">
            Feature flags
          </a>
        </div>
      </header>

      <section aria-labelledby="pending-heading" className="mt-10">
        <h2 id="pending-heading" className="display text-3xl">
          Waiting for review
        </h2>
        {pending.length === 0 ? (
          <p className="mt-4 rounded-2xl border border-dashed border-rule px-5 py-8 text-center text-sm text-ink-muted">
            Nothing waiting. Everything members added has been reviewed.
          </p>
        ) : (
          <ul className="mt-5 grid grid-cols-1 gap-4 xl:grid-cols-2">
            {pending.map((item) => (
              <PendingCard key={`${item.kind}-${item.id}`} item={item} targets={merge_targets[item.kind]} />
            ))}
          </ul>
        )}
      </section>

      <section aria-labelledby="all-heading" className="mt-16">
        <div className="flex flex-col gap-4 border-t border-ink pt-5 lg:flex-row lg:items-center lg:justify-between">
          <h2 id="all-heading" className="display text-3xl">
            Everything
          </h2>
          <div className="flex flex-wrap items-center gap-2">
            <Segmented<KindFilter>
              label="Kind"
              value={filters.kind}
              onChange={(kind) => apply({ kind })}
              options={[
                { value: 'all', label: 'All' },
                { value: 'tool', label: 'Tools' },
                { value: 'model', label: 'Models' },
              ]}
            />
            <Segmented<StatusFilter>
              label="Status"
              value={filters.status}
              onChange={(status) => apply({ status })}
              options={[
                { value: 'all', label: 'Any' },
                { value: 'pending', label: 'Pending' },
                { value: 'approved', label: 'Approved' },
                { value: 'hidden', label: 'Hidden' },
              ]}
            />
            <input
              type="search"
              aria-label="Search the catalog"
              placeholder="Search"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              className="w-full rounded-full border-0 bg-white px-4 py-1.5 text-sm ring-1 ring-rule focus:ring-2 focus:ring-every-blue sm:w-48"
            />
          </div>
        </div>
        <p className="eyebrow mt-4">{items.length === 1 ? '1 item' : `${items.length} items`}</p>
        {items.length === 0 ? (
          <p className="mt-6 text-sm text-ink-muted">Nothing matches.</p>
        ) : (
          <ul className="mt-2 divide-y divide-rule/70">
            {items.map((item) => (
              <ItemRow key={`${item.kind}-${item.id}`} item={item} targets={merge_targets[item.kind]} />
            ))}
          </ul>
        )}
      </section>
    </AppShell>
  )
}
