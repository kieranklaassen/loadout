import type { Errors } from '@inertiajs/core'
import { Head, router } from '@inertiajs/react'
import { useEffect, useRef, useState, type FormEvent, type ReactNode } from 'react'
import AppShell from '../../components/app_shell'
import Button from '../../components/button'
import Chip from '../../components/chip'
import Mark from '../../components/mark'
import SectionLabel from '../../components/section_label'
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

const heading = 'font-serif text-[32px] leading-[1.1] tracking-[-0.02em] text-fg'
const rowAction =
  'inline-flex min-h-11 items-center rounded-sharp px-2.5 text-caption text-fg-soft transition-colors hover:bg-raised hover:text-fg md:min-h-0 md:py-1'

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

function StatusChip({ status }: { status: CatalogStatus }) {
  switch (status) {
    case 'approved':
      return <Chip>Approved</Chip>
    case 'pending':
      return <Chip>Pending review</Chip>
    case 'hidden':
      return <Chip className="!text-fg-muted">Hidden</Chip>
    default: {
      const unreachable: never = status
      return unreachable
    }
  }
}

function setStatus(item: AdminCatalogItem, status: CatalogStatus) {
  router.patch(itemUrl(item), { item: { status } }, visit)
}

const formatDate = (iso: string, options: Intl.DateTimeFormatOptions) => new Date(iso).toLocaleDateString(undefined, options)

function Field({ label, children, className = '' }: { label: string; children: ReactNode; className?: string }) {
  return (
    <label className={`block ${className}`}>
      <SectionLabel>{label}</SectionLabel>
      <span className="field-box mt-1.5">{children}</span>
    </label>
  )
}

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
  const isModel = item.kind === 'model'
  const [values, setValues] = useState({
    name: item.name,
    maker: item.maker ?? '',
    released_on: item.released_on ?? '',
    vibe_check_url: item.vibe_check_url ?? '',
  })
  const [errors, setErrors] = useState<Errors>({})
  const set = (field: keyof typeof values) => (event: { target: { value: string } }) =>
    setValues({ ...values, [field]: event.target.value })

  const submit = (event: FormEvent) => {
    event.preventDefault()
    const { released_on, vibe_check_url, ...common } = values
    router.patch(
      itemUrl(item),
      { item: { ...common, ...(isModel ? { released_on, vibe_check_url } : {}), ...(approve ? { status: 'approved' } : {}) } },
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
    <form id={id} onSubmit={submit} className="grid grid-cols-1 gap-4 md:grid-cols-2">
      <Field label="Name">
        <input value={values.name} onChange={set('name')} />
      </Field>
      <Field label="Maker">
        <input value={values.maker} placeholder="Who makes it" onChange={set('maker')} />
      </Field>
      {isModel && (
        <>
          <Field label="Release date">
            <input type="date" value={values.released_on} onChange={set('released_on')} />
          </Field>
          <Field label="Vibe Check link">
            <input type="url" value={values.vibe_check_url} placeholder="https://checks.every.to/…" onChange={set('vibe_check_url')} />
          </Field>
          <p className="text-caption text-fg-muted md:col-span-2">
            Home lists a model as a launch only when it has both a release date and a Vibe Check link on an allowed Every host.
          </p>
        </>
      )}
      {Object.keys(errors).length > 0 && (
        <p role="alert" className="text-caption text-coral md:col-span-2">
          {Object.values(errors).map(String).join('. ')}
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
    if (!window.confirm(`Merge ${item.name} into ${chosen.name}? Everyone who picked ${item.name} moves over and ${item.name} is deleted.`)) return
    router.post(itemUrl(item, '/merge'), { target_id: chosen.id }, visit)
  }

  return (
    <div className="flex min-w-0 items-center gap-2">
      <div className="field-box min-w-0 flex-1">
        <select aria-label={`Merge ${item.name} into`} value={target} onChange={(e) => setTarget(e.target.value)}>
          <option value="">Merge into…</option>
          {options.map((option) => (
            <option key={option.id} value={option.id}>
              {option.name}
            </option>
          ))}
        </select>
      </div>
      <Button variant="secondary" disabled={!chosen} onClick={merge}>
        Merge
      </Button>
    </div>
  )
}

function Meta({ item }: { item: AdminCatalogItem }) {
  const added = formatDate(item.created_at, { month: 'short', day: 'numeric' })
  return (
    <p className="font-mono text-caption text-fg-muted">
      {kindLabel(item.kind)} · {item.slug}
      {item.created_by && (
        <>
          {' '}
          · added by <span className="text-fg-soft">{item.created_by.name}</span>
        </>
      )}{' '}
      · {added}
    </p>
  )
}

function PendingCard({ item, targets }: { item: AdminCatalogItem; targets: MergeTarget[] }) {
  return (
    <li className="panel p-5">
      <div className="mb-4 flex flex-wrap items-start gap-3">
        <Mark item={item} size="lg" />
        <div className="min-w-0 flex-1 basis-40">
          <p className="truncate font-medium text-fg">{item.name}</p>
          <Meta item={item} />
        </div>
        <StatusChip status={item.status} />
      </div>
      <ItemEditor id={`edit-${item.kind}-${item.id}`} item={item} approve />
      <div className="mt-5 flex flex-col gap-3 border-t border-line pt-4 sm:flex-row sm:items-center sm:justify-between">
        <div className="sm:w-80">
          <MergeControl item={item} targets={targets} />
        </div>
        <div className="flex items-center justify-end gap-2">
          <Button variant="ghost" onClick={() => setStatus(item, 'hidden')}>
            Hide
          </Button>
          <Button type="submit" form={`edit-${item.kind}-${item.id}`}>
            Approve
          </Button>
        </div>
      </div>
    </li>
  )
}

function ItemRow({ item, targets }: { item: AdminCatalogItem; targets: MergeTarget[] }) {
  const [open, setOpen] = useState(false)

  const remove = () => {
    if (window.confirm(`Delete ${item.name}? This only works when nobody has it on their toolbox.`)) router.delete(itemUrl(item), visit)
  }

  return (
    <li className="py-3">
      <div className="flex flex-wrap items-center gap-x-3 gap-y-2">
        <Mark item={item} size="sm" />
        <div className="min-w-0 flex-1 basis-48">
          <p className="truncate text-sm font-medium text-fg">
            {item.name}
            {item.maker && <span className="font-normal text-fg-muted"> · {item.maker}</span>}
          </p>
          <p className="truncate font-mono text-caption text-fg-muted">
            {kindLabel(item.kind).toLowerCase()} · {item.slug}
            {item.family && ` · ${item.family}`}
            {item.released_on && ` · released ${formatDate(item.released_on, { month: 'short', day: 'numeric', year: 'numeric', timeZone: 'UTC' })}`}
          </p>
        </div>
        <StatusChip status={item.status} />
        <div className="flex shrink-0 items-center">
          <button type="button" className={rowAction} aria-expanded={open} onClick={() => setOpen((value) => !value)}>
            {open ? 'Close' : 'Edit'}
          </button>
          {item.status === 'hidden' ? (
            <button type="button" className={rowAction} onClick={() => setStatus(item, 'approved')}>
              Restore
            </button>
          ) : (
            <button type="button" className={rowAction} onClick={() => setStatus(item, 'hidden')}>
              Hide
            </button>
          )}
        </div>
      </div>
      {open && (
        <div className="panel mt-3 p-4 md:ml-10">
          <ItemEditor id={`row-${item.kind}-${item.id}`} item={item} approve={item.status === 'pending'} onDone={() => setOpen(false)} />
          <div className="mt-5 flex flex-col gap-3 border-t border-line pt-4 sm:flex-row sm:items-center sm:justify-between">
            <div className="sm:w-80">
              <MergeControl item={item} targets={targets} />
            </div>
            <div className="flex items-center justify-end gap-3">
              <button type="button" onClick={remove} className={`${rowAction} !text-coral`}>
                Delete
              </button>
              <Button type="submit" form={`row-${item.kind}-${item.id}`}>
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
    <div role="group" aria-label={label} className="inline-flex rounded-sharp border border-line bg-field p-0.5">
      {options.map((option) => (
        <button
          key={option.value}
          type="button"
          aria-pressed={option.value === value}
          onClick={() => onChange(option.value)}
          className={`min-h-11 rounded-sharp px-3 text-caption transition-colors md:min-h-0 md:py-1 ${option.value === value ? 'bg-sky text-on-light' : 'text-fg-soft hover:text-fg'}`}
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
    <AppShell>
      <Head title="Catalog review" />

      <header className="flex flex-col gap-6 border-b border-line pb-8 md:flex-row md:items-end md:justify-between">
        <div>
          <SectionLabel as="p">Admin</SectionLabel>
          <h1 className="mt-3 font-serif text-[44px] leading-[1.02] tracking-[-0.02em] text-fg md:text-[56px]">Catalog review</h1>
          <p className="mt-3 max-w-lg text-fg-soft">
            Members add tools and models while picking. Approve them, tidy the name, fold duplicates into the real thing, or hide them
            from pickers. Set a model&rsquo;s release date and Vibe Check link to list it as a launch.
          </p>
        </div>
        <div className="flex items-end gap-6">
          <dl className="flex gap-6">
            {(['pending', 'approved', 'hidden'] as const).map((status) => (
              <div key={status} className="flex flex-col-reverse">
                <dt>
                  <SectionLabel className="mt-1 block">{status}</SectionLabel>
                </dt>
                <dd className="font-serif text-3xl tabular-nums text-fg">{counts[status]}</dd>
              </div>
            ))}
          </dl>
          <a href="/admin/flipper" className="text-link text-sm">
            Feature flags
          </a>
        </div>
      </header>

      <section aria-labelledby="pending-heading" className="mt-12">
        <h2 id="pending-heading" className={heading}>
          Waiting for review
        </h2>
        {pending.length === 0 ? (
          <p className="mt-4 rounded-soft border border-dashed border-line-strong px-5 py-8 text-center text-sm text-fg-muted">
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
        <div className="flex flex-col gap-4 border-t border-line pt-6 lg:flex-row lg:items-center lg:justify-between">
          <h2 id="all-heading" className={heading}>
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
            <div className="field-box w-full sm:w-52">
              <input type="search" aria-label="Search the catalog" placeholder="Search" value={query} onChange={(e) => setQuery(e.target.value)} />
            </div>
          </div>
        </div>
        <SectionLabel as="p" className="mt-4">
          {items.length === 1 ? '1 item' : `${items.length} items`}
        </SectionLabel>
        {items.length === 0 ? (
          <p className="mt-6 text-sm text-fg-muted">Nothing matches.</p>
        ) : (
          <ul className="mt-2 divide-y divide-line">
            {items.map((item) => (
              <ItemRow key={`${item.kind}-${item.id}`} item={item} targets={merge_targets[item.kind]} />
            ))}
          </ul>
        )}
      </section>
    </AppShell>
  )
}
