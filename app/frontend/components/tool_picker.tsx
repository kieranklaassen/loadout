import type { LoadoutPick, PickerCatalog, PickerCategory, PicksByCategory } from '../types'
import CategoryCard, { type PickerMode } from './category_card'

/**
 * The category-by-category picker grid shared by onboarding (quick: tap tools,
 * pick models, mark the go-to) and /loadout/edit (full: plus notes and remove).
 * Controlled: the page owns the picks and decides when to save.
 */
export default function ToolPicker({
  categories,
  catalog,
  value,
  onChange,
  mode = 'quick',
}: {
  categories: PickerCategory[]
  catalog: PickerCatalog
  value: PicksByCategory
  onChange: (value: PicksByCategory) => void
  mode?: PickerMode
}) {
  const update = (slug: string, picks: LoadoutPick[]) => onChange({ ...value, [slug]: picks })

  return (
    <div className="grid items-start gap-5 lg:grid-cols-2">
      {categories.map((category, index) => (
        <CategoryCard
          key={category.slug}
          category={category}
          index={index}
          catalog={catalog}
          picks={value[category.slug] ?? []}
          onChange={(picks) => update(category.slug, picks)}
          mode={mode}
        />
      ))}
    </div>
  )
}
