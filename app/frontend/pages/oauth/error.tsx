import { Head } from '@inertiajs/react'
import AppShell from '../../components/app_shell'
import { ButtonLink } from '../../components/button'

export default function OauthError({ message }: { message: string }) {
  return (
    <AppShell>
      <Head title="Couldn't connect" />
      <div className="mx-auto max-w-xl animate-rise text-center">
        <p className="eyebrow">Connect an agent</p>
        <h1 className="display mt-3 text-4xl text-balance sm:text-5xl">That connection didn't check out</h1>
        <p className="mt-5 text-lg text-ink-soft">{message}</p>
        <p className="mt-3 text-sm text-ink-muted">Nothing was shared. Remove Loadout from your agent and add it again.</p>
        <div className="mt-8 flex justify-center">
          <ButtonLink href="/agents" variant="secondary">
            How to connect an agent
          </ButtonLink>
        </div>
      </div>
    </AppShell>
  )
}
