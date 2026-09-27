import type { ReactNode } from 'react'
import Avatar from '../avatar'

/** The person's photo, name and one-line bio, with their actions (Compare with mine, Copy link) beside them. */
export default function ProfileHeader({
  name,
  avatarUrl,
  bio,
  children,
}: {
  name: string
  avatarUrl: string | null
  bio: string | null
  children: ReactNode
}) {
  return (
    <section aria-label={name} className="flex flex-col gap-8 lg:flex-row lg:items-end lg:justify-between">
      <div className="flex min-w-0 flex-col gap-5 md:flex-row md:items-center md:gap-7">
        <Avatar name={name} src={avatarUrl} size="xl" />
        <div className="min-w-0">
          <h1 className="break-words font-serif text-[40px] leading-[1.02] tracking-[-0.02em] text-fg md:text-[56px]">{name}</h1>
          {bio && <p className="mt-2.5 max-w-[640px] text-lg leading-normal text-fg-soft">{bio}</p>}
        </div>
      </div>
      <div className="flex flex-wrap items-center gap-3">{children}</div>
    </section>
  )
}
