import { Head, Link, router } from '@inertiajs/react'
import { useEffect, useState } from 'react'
import AppShell from '../../components/app_shell'
import Button from '../../components/button'
import ConnectAgentCard from '../../components/connect_agent_card'
import ToolPicker from '../../components/tool_picker'
import { changedCategories, countPicks, toOperations } from '../../lib/picks'
import type { PickerData, PicksByCategory } from '../../types'

type Props = PickerData & { handle: string }

export default function LoadoutEdit({ categories, catalog, picks: saved, handle }: Props) {
  const [picks, setPicks] = useState<PicksByCategory>(saved)
  const [saving, setSaving] = useState(false)

  useEffect(() => setPicks(saved), [saved])

  const order = categories.map((category) => category.slug)
  const changed = changedCategories(saved, picks, order)
  const names = changed.map((slug) => categories.find((category) => category.slug === slug)?.name ?? slug)
  const counts = countPicks(picks)

  const save = () => {
    router.patch('/loadout', { operations: toOperations(picks, changed) }, {
      preserveScroll: true,
      preserveState: true,
      onStart: () => setSaving(true),
      onFinish: () => setSaving(false),
    })
  }

  return (
    <AppShell wide>
      <Head title="Edit your loadout" />

      <div className="grid animate-rise items-end gap-8 lg:grid-cols-[1fr_22rem]">
        <div>
          <p className="eyebrow">Your loadout</p>
          <h1 className="display mt-3 text-5xl text-ink sm:text-6xl">Keep it current.</h1>
          <p className="mt-4 max-w-xl text-lg text-ink-soft">
            {counts.picks === 0
              ? 'Nothing here yet. Tap the tools you use, category by category.'
              : `${counts.picks} ${counts.picks === 1 ? 'pick' : 'picks'} across ${counts.categories} ${counts.categories === 1 ? 'category' : 'categories'}. Swap models, star your go-to, and say why in a line.`}
          </p>
          <Link href={`/${handle}`} className="mt-5 inline-block text-sm text-ink underline decoration-rule underline-offset-4 hover:decoration-ink">
            View your profile →
          </Link>
        </div>
        <ConnectAgentCard compact />
      </div>

      <div className="mt-12">
        <ToolPicker categories={categories} catalog={catalog} value={picks} onChange={setPicks} mode="full" />
      </div>

      {changed.length > 0 && (
        <div className="sticky bottom-4 z-20 mt-8 animate-rise">
          <div className="mx-auto flex max-w-2xl items-center gap-3 rounded-full bg-ink py-2 pl-5 pr-2 text-paper shadow-[var(--shadow-lift)]">
            <span className="min-w-0 flex-1 truncate text-sm text-paper/80" aria-live="polite">
              Unsaved changes in {names.join(', ')}
            </span>
            <button type="button" onClick={() => setPicks(saved)} className="rounded-full px-3 py-2 text-sm text-paper/60 hover:text-paper">
              Discard
            </button>
            <Button variant="secondary" onClick={save} disabled={saving}>
              {saving ? 'Saving…' : 'Save changes'}
            </Button>
          </div>
        </div>
      )}
    </AppShell>
  )
}
