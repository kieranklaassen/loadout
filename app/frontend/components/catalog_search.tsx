import { useId, useState } from 'react'
import { draftItem, itemKey, searchItems } from '../lib/picks'
import type { CatalogItem } from '../types'
import ToolMark from './tool_mark'

type Option = { item: CatalogItem; isNew: boolean }

/**
 * Search the catalog, or add something it doesn't know yet. New names become
 * pending catalog items on save and show on the member's loadout right away.
 */
export default function CatalogSearch({
  items,
  exclude = [],
  onSelect,
  label,
  placeholder,
  autoFocus = false,
}: {
  items: CatalogItem[]
  exclude?: string[]
  onSelect: (item: CatalogItem) => void
  label: string
  placeholder: string
  autoFocus?: boolean
}) {
  const [query, setQuery] = useState('')
  const [active, setActive] = useState(0)
  const listId = useId()

  const trimmed = query.trim()
  const matches = searchItems(
    items.filter((item) => !exclude.includes(itemKey(item))),
    trimmed,
  )
  const exact = items.some((item) => item.name.toLowerCase() === trimmed.toLowerCase())
  const options: Option[] = [
    ...matches.map((item) => ({ item, isNew: false })),
    ...(trimmed.length >= 2 && !exact && trimmed.length <= 60 ? [{ item: draftItem(trimmed), isNew: true }] : []),
  ]
  const open = trimmed.length > 0 && options.length > 0

  const choose = (option: Option | undefined) => {
    if (!option) return
    onSelect(option.item)
    setQuery('')
    setActive(0)
  }

  return (
    <div className="relative">
      <label className="sr-only" htmlFor={`${listId}-input`}>
        {label}
      </label>
      <div className="flex items-center gap-2 rounded-full border border-rule bg-paper px-3.5 py-2 transition focus-within:border-ink/40 focus-within:bg-white">
        <svg viewBox="0 0 20 20" className="h-4 w-4 shrink-0 text-ink-muted" aria-hidden="true">
          <circle cx="9" cy="9" r="5.5" fill="none" stroke="currentColor" strokeWidth="1.6" />
          <path d="m13.5 13.5 3.5 3.5" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" />
        </svg>
        <input
          id={`${listId}-input`}
          role="combobox"
          aria-expanded={open}
          aria-controls={listId}
          aria-autocomplete="list"
          autoComplete="off"
          autoFocus={autoFocus}
          value={query}
          placeholder={placeholder}
          onChange={(event) => {
            setQuery(event.target.value)
            setActive(0)
          }}
          onKeyDown={(event) => {
            if (event.key === 'ArrowDown') {
              event.preventDefault()
              setActive((value) => Math.min(value + 1, options.length - 1))
            } else if (event.key === 'ArrowUp') {
              event.preventDefault()
              setActive((value) => Math.max(value - 1, 0))
            } else if (event.key === 'Enter') {
              event.preventDefault()
              choose(options[active])
            } else if (event.key === 'Escape') {
              setQuery('')
            }
          }}
          className="w-full border-0 bg-transparent p-0 text-sm text-ink placeholder:text-ink-muted focus:ring-0"
        />
      </div>
      {open && (
        <ul id={listId} role="listbox" className="card absolute inset-x-0 z-20 mt-2 max-h-72 overflow-auto p-1.5">
          {options.map((option, index) => (
            <li
              key={option.isNew ? 'new' : itemKey(option.item)}
              role="option"
              aria-selected={index === active}
              onMouseDown={(event) => {
                event.preventDefault()
                choose(option)
              }}
              onMouseEnter={() => setActive(index)}
              className={`flex cursor-pointer items-center gap-3 rounded-xl px-2.5 py-2 text-sm ${index === active ? 'bg-paper-deep' : ''}`}
            >
              <ToolMark item={option.item} size="sm" />
              {option.isNew ? (
                <span>
                  Add <span className="font-medium">“{option.item.name}”</span>
                  <span className="ml-2 text-xs text-ink-muted">new, reviewed later</span>
                </span>
              ) : (
                <span className="flex min-w-0 flex-1 items-baseline justify-between gap-3">
                  <span className="truncate font-medium">{option.item.name}</span>
                  {option.item.maker && <span className="truncate text-xs text-ink-muted">{option.item.maker}</span>}
                </span>
              )}
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}
