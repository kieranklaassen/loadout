import { Link, router } from '@inertiajs/react'
import { useEffect, useRef, useState, type ReactNode, type RefObject } from 'react'
import type { CatalogKind, Category, Count as CountValue, MarkItem } from '../../types'
import Count from '../count'
import Mark from '../mark'
import SectionLabel from '../section_label'
import { homeParams, kindHref, type HomeFilters, type PersonOption, type Show } from './filters'

export type SearchItem = {
  kind: CatalogKind
  item: MarkItem
  kinds: { category: Category; count: CountValue }[]
}

export type SearchData = { query: string; people: PersonOption[]; items: SearchItem[] }

export const MIN_QUERY = 2
const DEBOUNCE_MS = 250

const isEditable = (target: EventTarget | null) =>
  target instanceof HTMLElement && (target.isContentEditable || ['INPUT', 'TEXTAREA', 'SELECT'].includes(target.tagName))

/**
 * The header search: what is typed, the failure flag, and the input to focus. Results come
 * back as the page's `search` prop from a partial reload that keeps the URL and re-sends
 * the current filters. `/` focuses the field unless the reader is already typing.
 */
export function useSearch(filters: HomeFilters) {
  const [query, setQuery] = useState(filters.q ?? '')
  const [failed, setFailed] = useState(false)
  const inputRef = useRef<HTMLInputElement>(null)
  const { show, person, overall } = filters

  useEffect(() => {
    const trimmed = query.trim()
    if (trimmed.length < MIN_QUERY) return

    const busy = () => {
      setFailed(true)
      return false // handled here; keep Inertia from opening its error modal
    }
    const timer = window.setTimeout(() => {
      router.get(
        '/',
        { ...homeParams({ show, person, overall }), q: trimmed },
        {
          only: ['search'],
          preserveState: true,
          preserveScroll: true,
          preserveUrl: true,
          replace: true,
          onSuccess: () => setFailed(false),
          onHttpException: busy,
          onNetworkError: busy,
        },
      )
    }, DEBOUNCE_MS)
    return () => window.clearTimeout(timer)
  }, [query, show, person, overall])

  useEffect(() => {
    const focusOnSlash = (event: KeyboardEvent) => {
      if (event.key !== '/' || event.metaKey || event.ctrlKey || event.altKey || isEditable(event.target)) return
      event.preventDefault()
      inputRef.current?.focus()
    }
    document.addEventListener('keydown', focusOnSlash)
    return () => document.removeEventListener('keydown', focusOnSlash)
  }, [])

  return { query, setQuery, failed, inputRef }
}

/** The field that sits in the header. */
export function SearchField({ value, onChange, inputRef }: { value: string; onChange: (value: string) => void; inputRef: RefObject<HTMLInputElement | null> }) {
  return (
    <div role="search" className="relative">
      <svg aria-hidden="true" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" className="pointer-events-none absolute left-3.5 top-1/2 size-[18px] -translate-y-1/2 text-fg-muted">
        <circle cx="11" cy="11" r="7" />
        <path d="M20 20l-3.5-3.5" />
      </svg>
      <input
        ref={inputRef}
        type="search"
        name="q"
        value={value}
        onChange={(event) => onChange(event.target.value)}
        onKeyDown={(event) => event.key === 'Escape' && onChange('')}
        aria-label="Search tools, models and people"
        placeholder="Search tools, models or people"
        className="min-h-11 w-full rounded-sharp border border-line-strong bg-field py-2.5 pl-[42px] pr-11 text-[15px] text-fg placeholder:text-fg-muted md:min-h-0 [&::-webkit-search-cancel-button]:appearance-none"
      />
      <kbd aria-hidden="true" className="pointer-events-none absolute right-3 top-1/2 hidden -translate-y-1/2 rounded-sharp px-[7px] py-px font-mono text-caption text-fg-muted ring-1 ring-line-strong md:block">
        /
      </kbd>
    </div>
  )
}

function Group({ title, children }: { title: string; children: ReactNode }) {
  return (
    <div>
      <SectionLabel as="p">{title}</SectionLabel>
      <ul className="mt-3 space-y-3">{children}</ul>
    </div>
  )
}

function ItemGroup({ title, hits, show }: { title: string; hits: SearchItem[]; show: Show }) {
  if (hits.length === 0) return null

  return (
    <Group title={title}>
      {hits.map(({ item, kinds }) => (
        <li key={item.slug} className="flex items-start gap-3">
          <Mark item={item} size="sm" />
          <div className="min-w-0">
            <p className="font-semibold text-fg">{item.name}</p>
            <ul className="mt-1 space-y-0.5 text-caption">
              {kinds.map(({ category, count }) => (
                <li key={category.slug}>
                  <Link href={kindHref(category.slug, show)} className="text-link">
                    {category.name}
                  </Link>{' '}
                  <span className="text-fg-soft">
                    <Count count={count} />
                  </span>
                </li>
              ))}
            </ul>
          </div>
        </li>
      ))}
    </Group>
  )
}

/** What the search found, under the header. Shown only while something is typed. */
export function SearchResults({ query, search, failed, show }: { query: string; search?: SearchData; failed: boolean; show: Show }) {
  const trimmed = query.trim()
  if (!trimmed) return null

  const body = () => {
    if (trimmed.length < MIN_QUERY) return <p className="text-fg-soft">Type at least 2 characters</p>
    if (failed) return <p className="text-coral">Search is busy, try again in a minute</p>
    if (!search) return null
    if (search.people.length === 0 && search.items.length === 0) return <p className="text-fg-soft">Nothing matches “{search.query}”</p>

    return (
      <div className="grid gap-8 md:grid-cols-3">
        {search.people.length > 0 && (
          <Group title="People">
            {search.people.map((person) => (
              <li key={person.handle}>
                <Link href={`/${person.handle}`} className="text-link">
                  {person.name}
                </Link>
              </li>
            ))}
          </Group>
        )}
        <ItemGroup title="Tools" hits={search.items.filter((hit) => hit.kind === 'tool')} show={show} />
        <ItemGroup title="Models" hits={search.items.filter((hit) => hit.kind === 'model')} show={show} />
      </div>
    )
  }

  return (
    <section aria-label="Search results" aria-live="polite" className="panel mb-10 p-5 md:p-6">
      {body()}
    </section>
  )
}
