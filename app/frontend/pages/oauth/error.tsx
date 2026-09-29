import { Head } from '@inertiajs/react'
import AppShell from '../../components/app_shell'
import { ButtonLink } from '../../components/button'
import SectionLabel from '../../components/section_label'

/** A malformed authorize request. It never links back to the client: anyone can register one. */
export default function OauthError({ message }: { message: string }) {
  return (
    <AppShell header="logo">
      <Head title="Couldn’t connect" />
      <div className="mx-auto max-w-xl pt-4 text-center md:pt-10">
        <SectionLabel as="p">Connect an agent</SectionLabel>
        <h1 className="font-serif leading-[1.02] tracking-[-0.02em] mt-3 text-[36px] text-balance md:text-[48px]">That connection didn’t check out</h1>
        <p className="mt-5 text-lg leading-normal text-fg-soft">{message}</p>
        <p className="mt-3 text-sm text-fg-muted">Nothing was shared. Remove Toolbox from your agent and add it again.</p>
        <div className="mt-8 flex justify-center">
          <ButtonLink href="/agents" variant="secondary">
            How to connect an agent
          </ButtonLink>
        </div>
      </div>
    </AppShell>
  )
}
