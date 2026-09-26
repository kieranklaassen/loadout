import { Head, usePage } from '@inertiajs/react'
import AppShell from '../../components/app_shell'
import Avatar from '../../components/avatar'
import { buttonClasses } from '../../components/button'
import ToolMark from '../../components/tool_mark'
import { LoadoutGlyph } from '../../components/wordmark'
import type { OauthAuthorizationParams, SharedProps } from '../../types'

type ConsentProps = {
  client: { name: string; uri: string | null; hue: number; monogram: string }
  redirect_host: string
  authorization: OauthAuthorizationParams
  authenticity_token: string
}

const CAN = [
  'See your loadout and your recent changes',
  'Search the Loadout catalog of tools and models',
  'Add, switch, and remove the tools and models in your loadout',
]

const CANNOT = ['Change who can see your profile', 'Change your link or delete your account']

export default function Consent({ client, redirect_host, authorization, authenticity_token }: ConsentProps) {
  const { current_user } = usePage<SharedProps>().props

  return (
    <AppShell>
      <Head title={`Connect ${client.name}`} />
      <div className="mx-auto max-w-xl animate-rise">
        <div className="flex items-center justify-center gap-3" aria-hidden="true">
          <ToolMark item={{ name: client.name, hue: client.hue, monogram: client.monogram }} size="lg" />
          <span className="flex items-center gap-1.5 text-rule">
            <span className="h-1.5 w-1.5 rounded-full bg-current" />
            <span className="h-1.5 w-1.5 rounded-full bg-current" />
            <span className="h-1.5 w-1.5 rounded-full bg-every-blue" />
          </span>
          <span className="inline-flex h-14 w-14 items-center justify-center rounded-2xl border border-rule bg-white text-ink">
            <LoadoutGlyph className="h-7 w-7" />
          </span>
        </div>

        <p className="eyebrow mt-10 text-center">Connect an agent</p>
        <h1 className="display mt-3 text-center text-4xl text-balance sm:text-5xl">
          {client.name} wants to read and update your Loadout
        </h1>

        {current_user && (
          <p className="mt-5 flex items-center justify-center gap-2 text-sm text-ink-muted">
            <Avatar name={current_user.name} src={current_user.avatar_url} size="sm" />
            Signed in as <span className="font-medium text-ink">{current_user.name}</span>
          </p>
        )}

        <div className="card mt-10 divide-y divide-rule overflow-hidden">
          <section className="px-6 py-5 sm:px-7">
            <h2 className="eyebrow">It will be able to</h2>
            <ul className="mt-3 space-y-2.5">
              {CAN.map((line) => (
                <li key={line} className="flex gap-3 text-[0.95rem] text-ink">
                  <span aria-hidden="true" className="mt-2 h-1.5 w-1.5 shrink-0 rounded-full bg-every-blue" />
                  {line}
                </li>
              ))}
            </ul>
          </section>
          <section className="px-6 py-5 sm:px-7">
            <h2 className="eyebrow">It can't</h2>
            <ul className="mt-3 space-y-2.5">
              {CANNOT.map((line) => (
                <li key={line} className="flex gap-3 text-[0.95rem] text-ink-soft">
                  <span aria-hidden="true" className="mt-2 h-1.5 w-1.5 shrink-0 rounded-full border border-ink-muted" />
                  {line}
                </li>
              ))}
            </ul>
          </section>
          <section className="bg-paper-deep/60 px-6 py-4 text-sm text-ink-soft sm:px-7">
            After you approve, you'll go back to{' '}
            <span className="break-words font-mono text-[0.8rem] text-ink">{redirect_host}</span>
            {client.uri && (
              <>
                {' '}
                ·{' '}
                <a href={client.uri} target="_blank" rel="noreferrer noopener" className="underline decoration-rule underline-offset-4 hover:text-ink">
                  about this app
                </a>
              </>
            )}
          </section>
        </div>

        {/* A native form post, not an Inertia visit: the answer redirects to the agent's own URL scheme or loopback server. */}
        <form method="post" action="/oauth/authorize" className="mt-8 flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
          <input type="hidden" name="authenticity_token" value={authenticity_token} />
          {Object.entries(authorization).map(([name, value]) => (
            <input key={name} type="hidden" name={name} value={value ?? ''} />
          ))}
          <button type="submit" name="decision" value="deny" className={buttonClasses('secondary', 'lg')}>
            Deny
          </button>
          <button type="submit" name="decision" value="approve" className={buttonClasses('blue', 'lg')}>
            Approve {client.name}
          </button>
        </form>

        <p className="mt-6 text-center text-xs text-ink-muted">
          You can disconnect it at any time from{' '}
          <a href="/agents" className="underline decoration-rule underline-offset-4 hover:text-ink">
            Connected agents
          </a>
          . Only approve apps you just set up yourself.
        </p>
      </div>
    </AppShell>
  )
}
