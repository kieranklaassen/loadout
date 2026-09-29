import { Head, Link, router } from '@inertiajs/react'
import { useState, type FormEvent, type ReactNode } from 'react'
import AppShell from '../../components/app_shell'
import Button, { buttonClasses } from '../../components/button'
import HandleField, { useHandleStatus } from '../../components/handle_field'
import VisibilityChoice from '../../components/visibility_choice'
import { fieldErrors } from '../../lib/field_errors'
import { relativeDate } from '../../lib/relative_date'
import type { HandleAvailability, Visibility } from '../../types'

const BIO_LIMIT = 160

type Account = {
  name: string
  handle: string
  bio: string
  visibility: Visibility
}

type ConnectedAgent = {
  id: string
  name: string
  connected_at: string
  last_used_at: string | null
}

type Props = {
  account: Account
  agents: ConnectedAgent[]
  availability?: HandleAvailability
}

const heading = 'font-serif leading-[1.02] tracking-[-0.02em] text-[28px] md:text-[32px]'
const label = 'block text-sm font-semibold text-fg'
const hint = 'mt-1.5 text-caption text-fg-muted'

function FieldError({ message }: { message?: string }) {
  if (!message) return null
  return (
    <p role="alert" className="mt-2 text-sm text-coral">
      {message}
    </p>
  )
}

function Section({ id, title, className = '', children }: { id: string; title: string; className?: string; children: ReactNode }) {
  return (
    <section aria-labelledby={id} className={className}>
      <h2 id={id} className={heading}>
        {title}
      </h2>
      {children}
    </section>
  )
}

/** Name, link, bio and who can see it: one form, one Save. */
function PageForm({ account, availability }: { account: Account; availability?: HandleAvailability }) {
  const [values, setValues] = useState({ handle: account.handle, bio: account.bio, visibility: account.visibility })
  const [errors, setErrors] = useState<Record<string, string>>({})
  const [processing, setProcessing] = useState(false)
  const [saved, setSaved] = useState(false)
  const { handle, status } = useHandleStatus({ value: values.handle, initial: account.handle, availability, error: errors.handle })

  const edit = (change: Partial<typeof values>) => {
    setValues({ ...values, ...change })
    setErrors({})
    setSaved(false)
  }
  const dirty = handle !== account.handle || values.bio !== account.bio || values.visibility !== account.visibility
  const canSave = dirty && status.tone === 'ok' && !processing

  const submit = (event: FormEvent) => {
    event.preventDefault()
    if (!canSave) return
    router.patch('/settings', { handle, bio: values.bio, visibility: values.visibility }, {
      preserveScroll: true,
      preserveState: true,
      onStart: () => {
        setProcessing(true)
        setErrors({})
      },
      onFinish: () => setProcessing(false),
      onSuccess: () => setSaved(true),
      onError: (next) => setErrors(fieldErrors(next)),
    })
  }

  return (
    <form onSubmit={submit}>
      <Section id="page-heading" title="Your page">
        <div className="mt-5 flex flex-col gap-5">
          <div>
            <label htmlFor="name" className={label}>
              Name
            </label>
            <span className="field-box mt-2 max-w-[460px] border-line py-3">
              <input id="name" value={account.name} readOnly className="text-fg-soft" />
            </span>
            <p className={hint}>Shown on your page. Change it in your Every account.</p>
          </div>

          <HandleField value={values.handle} onChange={(next) => edit({ handle: next })} status={status} className="max-w-[460px]">
            Changing it breaks old links to your page.
          </HandleField>

          <div>
            <label htmlFor="bio" className={label}>
              One line about how you work
            </label>
            <textarea
              id="bio"
              name="bio"
              rows={2}
              maxLength={BIO_LIMIT}
              value={values.bio}
              onChange={(event) => edit({ bio: event.target.value })}
              aria-describedby="bio-count"
              className="mt-2 block w-full max-w-[460px] resize-none rounded-sharp border border-line-strong bg-field px-3.5 py-3 text-fg"
            />
            <div className="mt-1.5 flex max-w-[460px] items-start justify-between gap-4">
              <FieldError message={errors.bio} />
              <span id="bio-count" className="ml-auto font-mono text-caption text-fg-muted">
                {values.bio.length}/{BIO_LIMIT}
              </span>
            </div>
          </div>
        </div>
      </Section>

      <Section id="visibility-heading" title="Who can see it" className="mt-8">
        <div className="mt-4 max-w-[520px]">
          <VisibilityChoice
            value={values.visibility}
            onChange={(visibility) => edit({ visibility })}
            labelledBy="visibility-heading"
            error={errors.visibility}
          />
        </div>
      </Section>

      <div className="mt-6 flex flex-wrap items-center gap-x-4 gap-y-2">
        <Button type="submit" size="lg" disabled={!canSave}>
          Save changes
        </Button>
        <span role="status" className="text-caption text-fg-muted">
          {dirty ? 'Unsaved changes' : saved ? 'Saved' : 'No changes yet'}
        </span>
      </div>
    </form>
  )
}

function Agents({ agents }: { agents: ConnectedAgent[] }) {
  const revoke = (agent: ConnectedAgent) => {
    if (window.confirm(`Disconnect ${agent.name}? Its next request will be refused until you approve it again.`)) {
      router.delete(`/agents/${encodeURIComponent(agent.id)}`)
    }
  }

  return (
    <Section id="agents-heading" title="Connected agents">
      {agents.length === 0 ? (
        <p className="mt-3 text-[15px] leading-normal text-fg-soft">No agent is connected.</p>
      ) : (
        <ul className="mt-4 max-w-[520px] divide-y divide-line border-y border-line">
          {agents.map((agent) => (
            <li key={agent.id} className="flex items-center justify-between gap-4 py-3">
              <div className="min-w-0">
                <p className="truncate font-medium text-fg">{agent.name}</p>
                <p className="text-caption text-fg-muted" suppressHydrationWarning>
                  Connected {relativeDate(agent.connected_at)}
                  {agent.last_used_at && ` · last used ${relativeDate(agent.last_used_at)}`}
                </p>
              </div>
              <Button variant="secondary" aria-label={`Revoke ${agent.name}`} onClick={() => revoke(agent)}>
                Revoke
              </Button>
            </li>
          ))}
        </ul>
      )}
      <p className="mt-3 text-sm">
        <Link href="/agents" className="text-link">
          Set up an agent
        </Link>
      </p>
    </Section>
  )
}

function DeleteAccount({ handle }: { handle: string }) {
  const [confirmation, setConfirmation] = useState('')
  const [error, setError] = useState<string>()
  // The same test the server makes, so the button is live exactly when the request can succeed.
  const matches = confirmation.trim().toLowerCase() === handle

  const destroy = (event: FormEvent) => {
    event.preventDefault()
    if (matches) router.delete('/settings', { data: { confirmation }, onError: (errors) => setError(fieldErrors(errors).confirmation) })
  }

  return (
    <form onSubmit={destroy} aria-labelledby="delete-heading" className="max-w-[520px] rounded-soft border border-coral/50 p-6">
      <h2 id="delete-heading" className={`${heading} text-coral`}>
        Delete my account
      </h2>
      <p className="mt-2.5 text-[15px] leading-normal text-fg-soft">
        This removes your account, your picks, your history and your link. The team page counts update. It can’t be undone.
      </p>
      <label htmlFor="delete-confirmation" className={`${label} mt-5`}>
        Type {handle} to confirm
      </label>
      <span className="field-box mt-2 max-w-[300px] py-3">
        <input
          id="delete-confirmation"
          name="confirmation"
          value={confirmation}
          placeholder={handle}
          autoComplete="off"
          autoCapitalize="none"
          spellCheck={false}
          onChange={(event) => setConfirmation(event.target.value)}
        />
      </span>
      <FieldError message={error} />
      <button
        type="submit"
        disabled={!matches}
        className="mt-4 inline-flex min-h-11 items-center rounded-sharp border border-coral px-5 py-2.5 text-[15px] font-semibold text-coral transition-colors enabled:bg-coral enabled:text-on-light disabled:opacity-60 md:min-h-0"
      >
        Delete my account
      </button>
    </form>
  )
}

export default function SettingsShow({ account, agents, availability }: Props) {
  return (
    <AppShell>
      <Head title="Settings" />
      <div className="pt-4">
        <h1 className="font-serif leading-[1.02] tracking-[-0.02em] text-[40px] md:text-[56px]">Settings</h1>
        <div className="mt-8 grid grid-cols-1 gap-12 md:grid-cols-[minmax(0,600px)_minmax(0,1fr)] md:gap-[72px]">
          <PageForm account={account} availability={availability} />
          <div className="flex flex-col gap-12">
            <Agents agents={agents} />
            <Section id="data-heading" title="Your data">
              <p className="mt-3 max-w-[460px] text-[15px] leading-normal text-fg-soft">
                Every change to your toolbox is kept with its date, so the team page can show what switched when. You can download all of it.
              </p>
              <a href="/settings/history" download className={`${buttonClasses('secondary')} mt-4`}>
                Download my history
              </a>
            </Section>
            <DeleteAccount handle={account.handle} />
          </div>
        </div>
      </div>
    </AppShell>
  )
}
