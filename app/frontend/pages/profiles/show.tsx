import { Head, usePage } from '@inertiajs/react'
import { useState } from 'react'
import AppShell from '../../components/app_shell'
import Button, { ButtonLink } from '../../components/button'
import LoadoutTable from '../../components/profile/loadout_table'
import ProfileHeader from '../../components/profile/profile_header'
import { CopyLinkButton } from '../../components/copy_link_button'
import type { PersonData } from '../../components/team/person_view'
import type { RankedPick, SharedProps } from '../../types'

export type ProfileProps = PersonData & {
  bio: string | null
  /** A signed-in member, not the owner, who has ranked something. */
  viewer_can_compare: boolean
  /** The viewer's own picks by kind slug, for Compare with mine; empty when they cannot compare. */
  you: Record<string, RankedPick[]>
  copy_url: string
}

function EmptyLoadout({ firstName, owner }: { firstName: string; owner: boolean }) {
  return (
    <div className="panel mt-8 px-6 py-10 md:px-14 md:py-14">
      <p className="font-serif text-[28px] leading-[1.1] tracking-[-0.02em] text-fg md:text-[32px]">{firstName} has not ranked any tools yet.</p>
      {owner && (
        <>
          <p className="mt-4 max-w-[560px] text-lg leading-[1.55] text-fg-soft">Rank up to three tools for each kind of work. You choose who sees them.</p>
          <ButtonLink href="/loadout/edit" size="lg" className="mt-7">
            Rank your first tools
          </ButtonLink>
        </>
      )}
    </div>
  )
}

export default function ProfileShow({ person, ranked_count, kinds, bio, viewer_can_compare, you, copy_url }: ProfileProps) {
  const { current_user } = usePage<SharedProps>().props
  const [comparing, setComparing] = useState(false)
  const firstName = person.name.split(/\s+/)[0]
  const ranked = kinds.filter((kind) => kind.picks.length > 0)
  const unranked = kinds.filter((kind) => kind.picks.length === 0)

  return (
    <AppShell>
      <Head title={`${person.name}'s loadout`} />

      <ProfileHeader name={person.name} avatarUrl={person.avatar_url} bio={bio}>
        {viewer_can_compare && (
          <Button variant="secondary" aria-pressed={comparing} className="aria-pressed:border-sky aria-pressed:bg-raised" onClick={() => setComparing((value) => !value)}>
            Compare with mine
          </Button>
        )}
        <CopyLinkButton url={copy_url} />
      </ProfileHeader>

      <section aria-labelledby="loadout" className="mt-14 md:mt-16">
        <div className="flex flex-wrap items-baseline justify-between gap-x-6 gap-y-2 border-b border-line-strong pb-4">
          <h2 id="loadout" className="font-serif text-[32px] leading-[1.1] tracking-[-0.02em] text-fg md:text-4xl">
            {firstName}'s loadout
          </h2>
          <p className="text-sm text-fg-muted">
            {ranked_count} of {kinds.length} ranked
          </p>
        </div>

        {ranked.length === 0 ? (
          <EmptyLoadout firstName={firstName} owner={current_user?.handle === person.handle} />
        ) : (
          <>
            <LoadoutTable kinds={ranked} you={comparing ? you : null} />
            {unranked.length > 0 && <p className="mt-5 text-sm text-fg-muted">Not ranked yet: {unranked.map((kind) => kind.category.name).join(', ')}</p>}
          </>
        )}
      </section>
    </AppShell>
  )
}
