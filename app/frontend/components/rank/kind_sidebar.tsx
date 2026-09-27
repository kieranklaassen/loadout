import { Link } from '@inertiajs/react'
import { useEffect, useRef } from 'react'
import { progressLabel, type EditorKind } from '../../lib/ranking'

/** The kinds of work as links, each with how far along it is. A phone gets them as one scrolling row. */
export default function KindSidebar({ kinds, selected }: { kinds: EditorKind[]; selected: string }) {
  const current = useRef<HTMLAnchorElement>(null)

  useEffect(() => {
    current.current?.scrollIntoView?.({ block: 'nearest', inline: 'center' })
  }, [selected])

  return (
    <nav aria-label="Kinds of work" className="lg:w-[300px] lg:flex-none">
      <ul className="-mx-4 flex gap-2 overflow-x-auto px-4 pb-2 md:-mx-8 md:px-8 lg:mx-0 lg:block lg:overflow-visible lg:border-t lg:border-line-strong lg:p-0">
        {kinds.map((kind) => {
          const active = kind.category.slug === selected
          return (
            <li key={kind.category.slug} className="shrink-0 lg:shrink">
              <Link
                ref={active ? current : undefined}
                href={`/loadout/edit?kind=${kind.category.slug}`}
                preserveScroll
                preserveState
                aria-current={active ? 'page' : undefined}
                className={`flex min-h-11 flex-col justify-center gap-0.5 rounded-soft px-3.5 py-2.5 lg:flex-row lg:items-center lg:justify-between lg:rounded-none lg:py-3 ${
                  active ? 'bg-panel ring-1 ring-sky' : 'ring-1 ring-line lg:border-b lg:border-line lg:ring-0'
                }`}
              >
                <span className="font-serif text-lg">{kind.category.name}</span>
                <span className={`text-caption ${active ? 'text-fg-soft' : 'text-fg-muted'}`}>{progressLabel(kind)}</span>
              </Link>
            </li>
          )
        })}
      </ul>
    </nav>
  )
}
