import { Head, Link } from '@inertiajs/react'
import AppShell from '../../components/app_shell'
import KindPanel from '../../components/rank/kind_panel'
import KindSidebar from '../../components/rank/kind_sidebar'
import { startedCount, type Catalog, type EditorKind, type Enums, type TeamTop } from '../../lib/ranking'
import { VISIBILITY_STATUS } from '../../lib/visibility_copy'
import type { Visibility } from '../../types'

type Props = {
  kinds: EditorKind[]
  catalog: Catalog
  enums: Enums
  selected_kind: string
  visibility: Visibility
  team_top: TeamTop
}

export default function ToolboxEdit({ kinds, catalog, enums, selected_kind, visibility, team_top }: Props) {
  const kind = kinds.find((candidate) => candidate.category.slug === selected_kind) ?? kinds[0]!

  return (
    <AppShell>
      <Head title="Rank your tools" />

      <div className="flex flex-col gap-6 md:flex-row md:items-end md:justify-between">
        <div>
          <h1 className="font-serif text-[40px] leading-[1.02] tracking-[-0.02em] md:text-[56px]">Rank your tools</h1>
          <p className="mt-3 max-w-[640px] text-lg text-fg-soft">
            Pick your top three tools for each kind of work, and how you run them. Your first pick counts most. Skip any you like.
          </p>
        </div>
        <div className="md:max-w-[340px] md:text-right">
          <p className="font-mono text-sm text-fg-soft">
            <span className="text-fg">{startedCount(kinds)}</span> of {kinds.length} kinds started
          </p>
          <p className="mt-1 text-caption text-fg-muted">Changes save as you go. Suggested picks stay private until you confirm.</p>
          <p className="mt-2 text-caption text-fg-soft">
            {VISIBILITY_STATUS[visibility]}{' '}
            <Link href="/settings" className="text-link">
              Change who can see it
            </Link>
          </p>
        </div>
      </div>

      <div className="mt-8 flex flex-col gap-6 lg:flex-row lg:gap-12">
        <KindSidebar kinds={kinds} selected={kind.category.slug} />
        <KindPanel key={kind.category.slug} kind={kind} catalog={catalog} enums={enums} teamTop={team_top} />
      </div>
    </AppShell>
  )
}
