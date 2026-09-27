import { Head, Link, usePage } from '@inertiajs/react'
import everyLogo from '../../assets/every-logo.svg'
import AppShell from '../../components/app_shell'
import Button from '../../components/button'
import CapabilityLists, { type Capabilities } from '../../components/capabilities'
import Mark from '../../components/mark'
import type { OauthAuthorizationParams, SharedProps } from '../../types'

type ConsentProps = {
  /** `mark` is set only when `known`: an https redirect on a host that belongs to the product. */
  client: { name: string; redirect_host: string; mark: string | null; known: boolean }
  redirect_host: string
  authorization: OauthAuthorizationParams
  authenticity_token: string
  capabilities: Capabilities
}

const LOOPBACK_HOSTS = ['localhost', '127.0.0.1', '[::1]']

export default function Consent({ client, redirect_host, authorization, authenticity_token, capabilities }: ConsentProps) {
  const { current_user } = usePage<SharedProps>().props

  return (
    <AppShell header="logo">
      <Head title={`Connect ${client.name}`} />
      <section aria-labelledby="consent-heading" className="panel mx-auto mt-4 w-full max-w-[560px] p-6 md:mt-8 md:p-9">
        <div className="flex items-center justify-center gap-3.5" aria-hidden="true">
          <Mark item={{ name: client.name, kind: 'tool', mark: client.known ? client.mark : null }} size="xl" />
          <span className="text-[22px] text-fg-muted">↔</span>
          <img src={everyLogo} alt="" className="h-7 w-auto invert" />
        </div>

        <h1 id="consent-heading" className="font-serif leading-[1.02] tracking-[-0.02em] mt-6 text-center text-[32px] text-balance [overflow-wrap:anywhere] md:text-[40px]">
          {client.name} wants to fill in your loadout
        </h1>
        {current_user && (
          <p className="mt-2.5 text-center text-[15px] text-fg-muted">
            Signed in as <span className="font-medium text-fg">{current_user.name}</span>
          </p>
        )}

        <CapabilityLists capabilities={capabilities} className="mt-2" />
        <p className="mt-4 text-[15px] leading-normal text-fg-soft">{capabilities.webmcp_note}</p>
        <p className="mt-4 text-[15px] leading-normal text-fg-soft">
          After you allow, you go back to <span className="font-mono text-caption text-fg [overflow-wrap:anywhere]">{redirect_host}</span>
          {LOOPBACK_HOSTS.includes(redirect_host) && ', an app running on your computer'}.
        </p>

        {/* A native form post, not an Inertia visit: the answer redirects to the agent's own URL scheme or loopback server. */}
        <form method="post" action="/oauth/authorize" className="mt-6 flex flex-col gap-3 md:flex-row">
          <input type="hidden" name="authenticity_token" value={authenticity_token} />
          {Object.entries(authorization).map(([name, value]) => (
            <input key={name} type="hidden" name={name} value={value ?? ''} />
          ))}
          <Button type="submit" name="decision" value="approve" size="lg" className="flex-1">
            Allow
          </Button>
          <Button type="submit" name="decision" value="deny" variant="ghost" size="lg" className="flex-1 border border-fg-muted">
            Deny
          </Button>
        </form>

        <p className="mt-4 text-center text-caption leading-normal text-fg-muted">
          You can turn this off any time on the{' '}
          <Link href="/agents" className="text-link">
            Agents page
          </Link>
          . Only allow apps you just set up yourself.
        </p>
      </section>
    </AppShell>
  )
}
