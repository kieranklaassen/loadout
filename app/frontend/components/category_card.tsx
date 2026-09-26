import { useState, type CSSProperties } from 'react'
import { NOTE_LIMIT, hasTool, itemKey, makePrimary, pickKey, removePick, setModel, setNote, toggleTool } from '../lib/picks'
import type { CatalogItem, LoadoutPick, PickerCatalog, PickerCategory } from '../types'
import CatalogSearch from './catalog_search'
import ToolMark from './tool_mark'

export type PickerMode = 'quick' | 'full'

const MAX_MODEL_CHIPS = 5

function bySlugs(items: CatalogItem[], slugs: string[]) {
  const index = new Map(items.map((item) => [item.slug, item]))
  return slugs.flatMap((slug) => index.get(slug) ?? [])
}

function ToolTile({ tool, selected, onToggle }: { tool: CatalogItem; selected: boolean; onToggle: () => void }) {
  return (
    <button
      type="button"
      aria-pressed={selected}
      onClick={onToggle}
      className={`group inline-flex items-center gap-2 rounded-full py-1.5 pl-1.5 pr-3.5 text-sm transition active:scale-[0.97] ${
        selected
          ? 'bg-ink text-paper shadow-[0_8px_20px_-12px_rgb(18_18_18/0.9)]'
          : 'bg-paper text-ink ring-1 ring-rule hover:bg-white hover:ring-ink/25'
      }`}
    >
      <ToolMark item={tool} size="sm" className={selected ? 'border-transparent' : ''} />
      <span className="font-medium">{tool.name}</span>
      {selected && (
        <svg viewBox="0 0 16 16" className="h-3.5 w-3.5 text-every-lime" aria-hidden="true">
          <path d="m3.5 8.5 3 3 6-7" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      )}
    </button>
  )
}

function GoToButton({ primary, onClick, solo }: { primary: boolean; onClick: () => void; solo: boolean }) {
  if (solo) return <span className="eyebrow !text-every-blue">Go-to</span>
  return (
    <button
      type="button"
      aria-pressed={primary}
      onClick={onClick}
      className={`inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-medium transition ${
        primary ? 'bg-every-blue text-white' : 'text-ink-muted ring-1 ring-rule hover:text-ink hover:ring-ink/25'
      }`}
    >
      <svg viewBox="0 0 16 16" className="h-3 w-3" aria-hidden="true">
        <path
          d="M8 1.8l1.9 3.9 4.3.6-3.1 3 .7 4.3L8 11.6l-3.8 2 .7-4.3-3.1-3 4.3-.6z"
          fill={primary ? 'currentColor' : 'none'}
          stroke="currentColor"
          strokeWidth="1.3"
          strokeLinejoin="round"
        />
      </svg>
      {primary ? 'Go-to' : 'Make go-to'}
    </button>
  )
}

function PickRow({
  pick,
  suggestedModels,
  allModels,
  solo,
  mode,
  onModel,
  onPrimary,
  onNote,
  onRemove,
}: {
  pick: LoadoutPick
  suggestedModels: CatalogItem[]
  allModels: CatalogItem[]
  solo: boolean
  mode: PickerMode
  onModel: (model: CatalogItem | null) => void
  onPrimary: () => void
  onNote: (note: string) => void
  onRemove: () => void
}) {
  const [searching, setSearching] = useState(false)
  const chips = suggestedModels.slice(0, MAX_MODEL_CHIPS)
  if (pick.model && !chips.some((model) => itemKey(model) === itemKey(pick.model!))) chips.push(pick.model)

  return (
    <li className="animate-rise py-4 first:pt-5">
      <div className="flex items-center gap-3">
        <ToolMark item={pick.tool} size="md" />
        <div className="min-w-0 flex-1">
          <p className="truncate font-medium text-ink">
            {pick.tool.name}
            {pick.model && <span className="font-normal text-ink-muted"> with {pick.model.name}</span>}
          </p>
          {pick.tool.pending && <p className="text-xs text-ink-muted">New to the catalog. Shows on your profile right away.</p>}
        </div>
        <GoToButton primary={pick.primary} solo={solo} onClick={onPrimary} />
        {mode === 'full' && (
          <button
            type="button"
            onClick={onRemove}
            aria-label={`Remove ${pick.tool.name}`}
            className="rounded-full p-1.5 text-ink-muted transition hover:bg-every-coral/15 hover:text-ink"
          >
            <svg viewBox="0 0 16 16" className="h-4 w-4" aria-hidden="true">
              <path d="m4 4 8 8M12 4l-8 8" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" />
            </svg>
          </button>
        )}
      </div>

      <div className="mt-3 flex flex-wrap items-center gap-1.5 pl-[3.25rem]" role="group" aria-label={`Model for ${pick.tool.name}`}>
        {chips.map((model) => {
          const selected = pick.model ? itemKey(pick.model) === itemKey(model) : false
          return (
            <button
              key={itemKey(model)}
              type="button"
              aria-pressed={selected}
              onClick={() => onModel(model)}
              className={`rounded-full px-2.5 py-1 font-mono text-[0.7rem] tracking-tight transition ${
                selected ? 'bg-every-sky text-ink ring-1 ring-ink/15' : 'text-ink-soft ring-1 ring-rule hover:ring-ink/25'
              }`}
            >
              {model.name}
            </button>
          )
        })}
        {!searching && (
          <button
            type="button"
            onClick={() => setSearching(true)}
            className="rounded-full px-2.5 py-1 font-mono text-[0.7rem] text-ink-muted hover:text-ink"
          >
            {chips.length ? 'Other model…' : 'Add a model…'}
          </button>
        )}
      </div>
      {searching && (
        <div className="mt-2 pl-[3.25rem]">
          <CatalogSearch
            items={allModels}
            label={`Search models for ${pick.tool.name}`}
            placeholder="Search or add a model"
            autoFocus
            onSelect={(model) => {
              onModel(model)
              setSearching(false)
            }}
          />
        </div>
      )}

      {mode === 'full' && (
        <div className="mt-3 pl-[3.25rem]">
          <label className="sr-only" htmlFor={`note-${pickKey(pick)}`}>
            Why {pick.tool.name}?
          </label>
          <textarea
            id={`note-${pickKey(pick)}`}
            rows={2}
            maxLength={NOTE_LIMIT}
            value={pick.note ?? ''}
            onChange={(event) => onNote(event.target.value)}
            placeholder={`Why ${pick.tool.name}? (optional)`}
            className="block w-full resize-none rounded-xl border-rule bg-paper px-3 py-2 font-serif text-[0.95rem] italic text-ink placeholder:not-italic placeholder:font-sans placeholder:text-sm placeholder:text-ink-muted focus:border-ink/40 focus:bg-white focus:ring-0"
          />
          {(pick.note?.length ?? 0) > NOTE_LIMIT - 60 && (
            <p className="mt-1 text-right font-mono text-[0.65rem] text-ink-muted">
              {pick.note?.length ?? 0}/{NOTE_LIMIT}
            </p>
          )}
        </div>
      )}
    </li>
  )
}

/** One category in the picker: tap suggested tools, search or add others, then choose a model and the go-to. */
export default function CategoryCard({
  category,
  index,
  catalog,
  picks,
  onChange,
  mode = 'quick',
}: {
  category: PickerCategory
  index: number
  catalog: PickerCatalog
  picks: LoadoutPick[]
  onChange: (picks: LoadoutPick[]) => void
  mode?: PickerMode
}) {
  const suggestedTools = bySlugs(catalog.tools, category.tool_slugs)
  const extraPicked = picks.map((pick) => pick.tool).filter((tool, i, all) =>
    !suggestedTools.some((item) => itemKey(item) === itemKey(tool)) && all.findIndex((t) => itemKey(t) === itemKey(tool)) === i,
  )
  const tiles = [...suggestedTools, ...extraPicked]
  const suggestedModels = bySlugs(catalog.models, category.model_slugs)
  const style = { animationDelay: `${Math.min(index, 8) * 40}ms` } as CSSProperties

  return (
    <section
      aria-labelledby={`category-${category.slug}`}
      style={style}
      className={`card min-w-0 animate-rise p-5 transition sm:p-6 ${picks.length ? 'ring-1 ring-ink/10' : ''}`}
    >
      <header className="flex items-start justify-between gap-4">
        <div>
          <p className="eyebrow">{String(index + 1).padStart(2, '0')}</p>
          <h3 id={`category-${category.slug}`} className="display mt-1 text-[1.7rem] text-ink">
            {category.name}
          </h3>
          {category.blurb && <p className="mt-1 text-sm text-ink-muted">{category.blurb}</p>}
        </div>
        {picks.length > 0 && (
          <span className="shrink-0 rounded-full bg-every-lime/60 px-2.5 py-1 font-mono text-[0.7rem] text-ink">
            {picks.length} picked
          </span>
        )}
      </header>

      {tiles.length > 0 && (
        <div className="mt-5 flex flex-wrap gap-2">
          {tiles.map((tool) => (
            <ToolTile key={itemKey(tool)} tool={tool} selected={hasTool(picks, tool)} onToggle={() => onChange(toggleTool(picks, tool))} />
          ))}
        </div>
      )}

      <div className="mt-3">
        <CatalogSearch
          items={catalog.tools}
          exclude={picks.map((pick) => itemKey(pick.tool))}
          label={`Search or add a tool for ${category.name}`}
          placeholder={tiles.length ? 'Something else? Search or add a tool' : 'Search or add a tool'}
          onSelect={(tool) => onChange(toggleTool(picks, tool))}
        />
      </div>

      {picks.length > 0 && (
        <ul className="mt-5 divide-y divide-rule border-t border-rule">
          {picks.map((pick, i) => (
            <PickRow
              key={`${itemKey(pick.tool)}-${i}`}
              pick={pick}
              mode={mode}
              solo={picks.length === 1}
              suggestedModels={suggestedModels}
              allModels={catalog.models}
              onModel={(model) => onChange(setModel(picks, i, model))}
              onPrimary={() => onChange(makePrimary(picks, i))}
              onNote={(note) => onChange(setNote(picks, i, note))}
              onRemove={() => onChange(removePick(picks, i))}
            />
          ))}
        </ul>
      )}
    </section>
  )
}
