import { Link } from '@inertiajs/react'
import { buttonClasses, ButtonLink } from '../button'

export type CallToAction = { label: string; href: string }

/** Join Every is another site; ranking your tools is in this app. Visitors also get Sign in. */
function Actions({ cta, signedIn }: { cta: CallToAction; signedIn: boolean }) {
  return (
    <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:gap-6">
      {signedIn ? (
        <ButtonLink href={cta.href} size="lg">
          {cta.label}
        </ButtonLink>
      ) : (
        <>
          <a href={cta.href} className={buttonClasses('primary', 'lg')}>
            {cta.label}
          </a>
          <Link href="/session/new" className="text-link text-sm text-fg-soft">
            Already a subscriber? Sign in
          </Link>
        </>
      )}
    </div>
  )
}

/** The one call to action at the bottom of Home, by viewer: Join Every for visitors, "Rank your first tools" for members with no picks. */
export default function Cta({ cta, signedIn }: { cta: CallToAction; signedIn: boolean }) {
  return (
    <section aria-label={signedIn ? 'Add your loadout' : 'Join Every'} className="panel bg-field px-6 py-10 md:px-14 md:py-14">
      <h2 className="max-w-[600px] font-serif text-[32px] leading-[1.08] tracking-[-0.02em] text-fg md:text-[44px]">
        {signedIn ? 'Your tools are not on this page yet' : 'The only subscription you need to stay at the edge of AI'}
      </h2>
      <p className="mt-4 max-w-[560px] text-lg leading-[1.55] text-fg-soft">
        {signedIn
          ? 'Rank up to three tools for each kind of work. You choose who sees them, and the default is only you.'
          : 'Ideas, apps, and training from practitioners who build with AI daily. Every subscribers can add their loadout and see what the team uses.'}
      </p>
      <div className="mt-7">
        <Actions cta={cta} signedIn={signedIn} />
      </div>
    </section>
  )
}

/** Nobody in this group has shared: say so plainly, and offer the same way in. */
export function EmptyState({ cta, signedIn }: { cta: CallToAction | null; signedIn: boolean }) {
  return (
    <section aria-label="Nothing shared yet" className="panel px-6 py-10 md:px-14 md:py-14">
      <h2 className="font-serif text-[32px] leading-[1.08] tracking-[-0.02em] text-fg md:text-[40px]">Nobody has shared a loadout yet</h2>
      {cta && (
        <>
          <p className="mt-4 max-w-[560px] text-lg leading-[1.55] text-fg-soft">
            {signedIn
              ? 'Rank the tools you use and share them with the Every team, and this page fills in.'
              : 'People on the Every team choose who sees their picks. When someone shares theirs, it shows up here.'}
          </p>
          <div className="mt-7">
            <Actions cta={cta} signedIn={signedIn} />
          </div>
        </>
      )}
    </section>
  )
}
