import { Head, Link, usePage } from '@inertiajs/react'
import AppShell from '../../components/app_shell'
import { ButtonLink } from '../../components/button'
import type { SharedProps } from '../../types'

/**
 * The one answer for a page that is not there or is not shared with the viewer, so the two
 * cannot be told apart. A signed-out visitor is offered sign-in: the server has already
 * remembered the page they asked for.
 */
export default function NotFound() {
  const { current_user } = usePage<SharedProps>().props

  return (
    <AppShell>
      <Head title="Page not found" />
      <div className="mx-auto max-w-[560px] py-12 text-center md:py-20">
        <h1 className="font-serif text-[40px] leading-[1.02] tracking-[-0.02em] text-fg md:text-[56px]">Page not found</h1>
        <p className="mt-5 text-lg leading-[1.55] text-fg-soft">There is no page at this address, or it is not shared with you.</p>
        {!current_user && (
          <p className="mt-6 text-fg-soft">
            <Link href="/session/new" className="text-link">
              If this was shared with the Every team, sign in
            </Link>
          </p>
        )}
        <ButtonLink href="/" variant="secondary" className="mt-9">
          Go to Home
        </ButtonLink>
      </div>
    </AppShell>
  )
}
