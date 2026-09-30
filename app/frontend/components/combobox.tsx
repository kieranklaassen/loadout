import { useEffect, useRef, useState, type KeyboardEvent, type ReactNode } from 'react'
import type { PickerList, PickerOption } from '../lib/picker'
import type { MarkItem } from '../types'
import Mark from './mark'
import { sectionLabelClasses } from './section_label'

// A type-to-filter picker (WAI-ARIA combobox with a listbox popup). Focus stays in the
// input; the arrow keys move the active row (aria-activedescendant), Enter picks it,
// Escape closes and restores the saved value. Rows come grouped from `list`, and the
// popup can end in "Show all" and "Add “query” as a suggestion".
//
// The popup is positioned against the nearest positioned ancestor: on phones the slot's
// field grid (so it spans both columns), from 768px the field itself.

type Row =
  | { type: 'clear'; label: string }
  | { type: 'option'; option: PickerOption }
  | { type: 'show-all'; hidden: number }
  | { type: 'add'; name: string }

const enabled = (row: Row) => row.type !== 'option' || !row.option.disabled

export default function Combobox({
  id,
  label,
  selected,
  placeholder,
  disabled = false,
  busy = false,
  clearLabel,
  showAllLabel,
  list,
  canAdd,
  onSelect,
  onAdd,
}: {
  id: string
  label: ReactNode
  selected: MarkItem | null | undefined
  placeholder: string
  disabled?: boolean
  /** A request is in flight: the input stays focusable and a pick is ignored upstream. */
  busy?: boolean
  /** Offer a first row that clears the value, while there is one. */
  clearLabel?: string
  showAllLabel: string
  list: (query: string, showAll: boolean) => PickerList
  canAdd?: (query: string, list: PickerList) => boolean
  onSelect: (slug: string | null) => void
  onAdd?: (name: string) => void
}) {
  const [open, setOpen] = useState(false)
  const [query, setQuery] = useState<string | null>(null)
  const [showAll, setShowAll] = useState(false)
  const [active, setActive] = useState(-1)
  const input = useRef<HTMLInputElement>(null)
  const labelId = `${id}-label`
  const listboxId = `${id}-listbox`
  const optionId = (index: number) => `${id}-option-${index}`

  const typed = query ?? ''
  const result = list(typed, showAll)
  const name = typed.trim().replace(/\s+/g, ' ')
  const rows: Row[] = [
    ...(clearLabel && selected && !typed.trim() ? [{ type: 'clear' as const, label: clearLabel }] : []),
    ...result.groups.flatMap((group) => group.options.map((option) => ({ type: 'option' as const, option }))),
    ...(result.hidden > 0 ? [{ type: 'show-all' as const, hidden: result.hidden }] : []),
    ...(onAdd && canAdd?.(typed, result) ? [{ type: 'add' as const, name }] : []),
  ]
  const firstEnabled = () => rows.findIndex(enabled)
  // The rows change as the query does, so the active row falls back to the first one that can be picked.
  const current = rows[active] && enabled(rows[active]) ? active : firstEnabled()
  let offset = rows[0]?.type === 'clear' ? 1 : 0
  const groupStarts = result.groups.map((group) => {
    const start = offset
    offset += group.options.length
    return start
  })

  useEffect(() => {
    if (open && current >= 0) document.getElementById(optionId(current))?.scrollIntoView?.({ block: 'nearest' })
  })

  const close = () => {
    setOpen(false)
    setQuery(null)
    setShowAll(false)
    setActive(-1)
  }

  const openList = () => {
    if (disabled) return
    setOpen(true)
    setActive(rows.findIndex((row) => row.type === 'option' && row.option.slug === selected?.slug))
  }

  const choose = (row: Row | undefined) => {
    if (!row || !enabled(row)) return
    if (row.type === 'show-all') {
      setShowAll(true)
      return
    }
    if (row.type === 'clear') onSelect(null)
    if (row.type === 'option' && row.option.slug !== selected?.slug) onSelect(row.option.slug)
    if (row.type === 'add') onAdd?.(row.name)
    close()
  }

  const move = (step: 1 | -1) => {
    if (rows.length === 0) return
    let next = current
    for (let tries = 0; tries < rows.length; tries++) {
      next = (next + step + rows.length) % rows.length
      if (enabled(rows[next]!)) break
    }
    setActive(next)
  }

  const onKeyDown = (event: KeyboardEvent<HTMLInputElement>) => {
    switch (event.key) {
      case 'ArrowDown':
      case 'ArrowUp':
        event.preventDefault()
        if (!open || event.altKey) openList()
        else move(event.key === 'ArrowDown' ? 1 : -1)
        break
      case 'Enter':
        if (!open) return
        event.preventDefault()
        choose(rows[current])
        break
      case 'Escape':
        if (!open && query === null) return
        event.preventDefault()
        close()
        break
      case 'Tab':
        close()
        break
    }
  }

  const rowClass = (at: number, extra = '') =>
    `flex min-h-11 cursor-pointer items-center gap-2.5 px-3 py-1.5 md:min-h-9 ${at === current ? 'bg-raised' : ''} ${extra}`
  const hover = (at: number) => () => at !== current && enabled(rows[at]!) && setActive(at)

  return (
    <div className="min-w-0 md:relative">
      <label id={labelId} htmlFor={id} className={`${sectionLabelClasses} mb-1.5 block`}>
        {label}
      </label>
      <div className={`field-box ${disabled ? 'opacity-60' : ''}`}>
        {selected && query === null && <Mark item={selected} size="sm" />}
        <input
          ref={input}
          id={id}
          type="text"
          role="combobox"
          autoComplete="off"
          autoCapitalize="off"
          spellCheck={false}
          aria-autocomplete="list"
          aria-expanded={open}
          aria-controls={listboxId}
          aria-activedescendant={open && current >= 0 ? optionId(current) : undefined}
          aria-disabled={busy || undefined}
          disabled={disabled}
          placeholder={placeholder}
          value={query ?? selected?.name ?? ''}
          onChange={(event) => {
            setQuery(event.target.value)
            setOpen(true)
            setActive(-1)
          }}
          onFocus={(event) => event.target.select()}
          onClick={() => !open && openList()}
          onBlur={close}
          onKeyDown={onKeyDown}
          className="truncate placeholder:text-fg-muted"
        />
        <button
          type="button"
          tabIndex={-1}
          aria-hidden="true"
          disabled={disabled}
          className="-my-2.5 -mr-3 self-stretch px-3 text-fg-muted"
          onMouseDown={(event) => event.preventDefault()}
          onClick={() => {
            input.current?.focus()
            if (open) close()
            else openList()
          }}
        >
          ▾
        </button>
      </div>

      {open && (
        <div
          id={listboxId}
          role="listbox"
          aria-labelledby={labelId}
          onMouseDown={(event) => event.preventDefault()}
          className="panel absolute inset-x-0 z-30 mt-1 max-h-[min(24rem,60vh)] overflow-y-auto py-1 md:right-auto md:w-[22rem] md:min-w-full"
        >
          {rows[0]?.type === 'clear' && (
            <div id={optionId(0)} role="option" aria-selected={false} className={rowClass(0, 'text-fg-soft')} onMouseMove={hover(0)} onClick={() => choose(rows[0])}>
              {rows[0].label}
            </div>
          )}
          {result.groups.map((group, groupAt) => (
            <div key={group.id} role="group" aria-labelledby={`${id}-group-${group.id}`}>
              <div id={`${id}-group-${group.id}`} role="presentation" className={`${sectionLabelClasses} px-3 pt-3 pb-1`}>
                {group.label}
              </div>
              {group.options.map((option, optionAt) => {
                const at = groupStarts[groupAt]! + optionAt
                const isSelected = option.slug === selected?.slug
                return (
                  <div
                    key={option.slug}
                    id={optionId(at)}
                    role="option"
                    aria-selected={isSelected}
                    aria-disabled={option.disabled || undefined}
                    className={rowClass(at, option.disabled ? 'cursor-not-allowed opacity-50' : '')}
                    onMouseMove={hover(at)}
                    onClick={() => choose(rows[at])}
                  >
                    <Mark item={option} size="xs" />
                    <span className="min-w-0 flex-1">
                      <span className="block truncate text-[15px]">
                        {option.name}
                        {option.pending && <span className="text-fg-muted"> · pending review</span>}
                      </span>
                      {option.maker && <span className="block truncate text-caption text-fg-muted">{option.maker}</span>}
                    </span>
                    {option.note && <span className="shrink-0 text-caption text-fg-muted">{option.note}</span>}
                    {isSelected && (
                      <span aria-hidden="true" className="shrink-0 text-fg-soft">
                        ✓
                      </span>
                    )}
                  </div>
                )
              })}
            </div>
          ))}
          {rows.length === 0 && <p className="px-3 py-2.5 text-caption text-fg-muted">No matches.</p>}
          {rows.map((row, at) =>
            row.type === 'show-all' ? (
              <div key="show-all" id={optionId(at)} role="option" aria-selected={false} className={rowClass(at, 'mt-1 border-t border-line text-caption text-fg-soft')} onMouseMove={hover(at)} onClick={() => choose(row)}>
                {showAllLabel} ({row.hidden} more)
              </div>
            ) : row.type === 'add' ? (
              <div key="add" id={optionId(at)} role="option" aria-selected={false} className={rowClass(at, 'mt-1 border-t border-line')} onMouseMove={hover(at)} onClick={() => choose(row)}>
                <span aria-hidden="true" className="text-fg-soft">
                  +
                </span>
                <span className="min-w-0 flex-1">
                  <span className="block truncate text-[15px]">Add “{row.name}” as a suggestion</span>
                  <span className="block text-caption text-fg-muted">Yours right away; an admin reviews it for the team.</span>
                </span>
              </div>
            ) : null,
          )}
          <p role="status" aria-live="polite" className="sr-only">
            {typed.trim() ? `${rows.filter((row) => row.type === 'option').length} matches` : ''}
          </p>
        </div>
      )}
    </div>
  )
}
