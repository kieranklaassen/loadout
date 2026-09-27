import { Head, router, useForm } from '@inertiajs/react'
import { useEffect, useState, type FormEvent, type ReactNode } from 'react'
import AppShell from '../../components/app_shell'
import Button from '../../components/button'
import ConnectAgentCard from '../../components/connect_agent_card'
import { HOST, normalizeHandle } from '../../lib/handles'
import type { HandleAvailability } from '../../types'

const BIO_LIMIT = 160

type Account = {
  handle: string
  bio: string
  public: boolean
  email: string
  every_member: boolean
}

type Props = {
  account: Account
  availability?: HandleAvailability
  errors?: { handle?: string; bio?: string; confirmation?: string }
}

function Section({ title, description, children, id }: { title: string; description: ReactNode; children: ReactNode; id: string }) {
  return (
    <section aria-labelledby={id} className="grid gap-5 border-t border-rule py-10 md:grid-cols-[16rem_1fr] md:gap-10">
      <div>
        <h2 id={id} className="display text-2xl text-ink">
          {title}
        </h2>
        <div className="mt-2 text-sm leading-relaxed text-ink-muted">{description}</div>
      </div>
      <div className="min-w-0">{children}</div>
    </section>
  )
}

function FieldError({ message }: { message?: string }) {
  if (!message) return null
  return (
    <p role="alert" className="mt-2 text-sm text-[#b4321f]">
      {message}
    </p>
  )
}

function HandleSection({ account, availability, error }: { account: Account; availability?: HandleAvailability; error?: string }) {
  const form = useForm({ handle: account.handle })
  const handle = normalizeHandle(form.data.handle)
  const changed = handle !== account.handle

  useEffect(() => {
    if (!handle || !changed) return
    const timer = window.setTimeout(() => {
      router.get('/handles/check', { handle }, { only: ['availability'], preserveState: true, preserveScroll: true, preserveUrl: true, replace: true })
    }, 220)
    return () => window.clearTimeout(timer)
  }, [handle, changed])

  const checked = changed && availability?.handle === handle ? availability : null
  const submit = (event: FormEvent) => {
    event.preventDefault()
    form.patch('/settings', { preserveScroll: true })
  }

  return (
    <Section
      id="settings-handle"
      title="Profile link"
      description="Changing it retires the old link right away: anyone opening it gets “not found”."
    >
      <form onSubmit={submit}>
        <label htmlFor="settings-handle-input" className="sr-only">
          Handle
        </label>
        <div className="flex items-baseline rounded-2xl border border-rule bg-white px-4 py-3 transition focus-within:border-ink/40">
          <span className="shrink-0 font-mono text-sm text-ink-muted">{HOST}/</span>
          <input
            id="settings-handle-input"
            value={form.data.handle}
            maxLength={30}
            autoCapitalize="none"
            spellCheck={false}
            onChange={(event) => form.setData('handle', event.target.value.toLowerCase().replace(/\s+/g, '-'))}
            className="min-w-0 flex-1 border-0 bg-transparent p-0 font-mono text-sm text-ink focus:ring-0"
          />
        </div>
        {changed && !error && (
          <p aria-live="polite" className={`mt-2 text-sm ${checked && !checked.available ? 'text-[#b4321f]' : 'text-ink-muted'}`}>
            {checked ? checked.message : 'Checking…'}
          </p>
        )}
        <FieldError message={error} />
        <Button type="submit" className="mt-4" disabled={!changed || !checked?.available || form.processing}>
          Change link
        </Button>
      </form>
    </Section>
  )
}

function BioSection({ account, error }: { account: Account; error?: string }) {
  const form = useForm({ bio: account.bio })
  const submit = (event: FormEvent) => {
    event.preventDefault()
    form.patch('/settings', { preserveScroll: true })
  }

  return (
    <Section id="settings-bio" title="Bio" description="One line under your name on your profile.">
      <form onSubmit={submit}>
        <label htmlFor="settings-bio-input" className="sr-only">
          Bio
        </label>
        <textarea
          id="settings-bio-input"
          rows={2}
          maxLength={BIO_LIMIT}
          value={form.data.bio}
          onChange={(event) => form.setData('bio', event.target.value)}
          placeholder="Designer at Every. Mostly Claude, sometimes Cursor."
          className="block w-full resize-none rounded-2xl border-rule bg-white px-4 py-3 font-serif text-lg text-ink placeholder:text-ink-muted focus:border-ink/40 focus:ring-0"
        />
        <div className="mt-2 flex items-center justify-between">
          <FieldError message={error} />
          <span className="ml-auto font-mono text-xs text-ink-muted">
            {form.data.bio.length}/{BIO_LIMIT}
          </span>
        </div>
        <Button type="submit" className="mt-3" disabled={form.data.bio === account.bio || form.processing}>
          Save bio
        </Button>
      </form>
    </Section>
  )
}

function VisibilitySection({ account }: { account: Account }) {
  const toggle = () => router.patch('/settings', { public: !account.public }, { preserveScroll: true })

  return (
    <Section
      id="settings-visibility"
      title="Visibility"
      description={
        account.every_member
          ? 'Private or public, your picks count anonymously in the Every map totals. Only public profiles are named there.'
          : 'Public profiles can be opened by anyone with the link, no sign-in needed.'
      }
    >
      <div className="flex items-start justify-between gap-6 rounded-2xl border border-rule bg-white p-5">
        <div>
          <p className="font-medium text-ink">{account.public ? 'Public' : 'Private'}</p>
          <p className="mt-1 text-sm text-ink-soft">
            {account.public
              ? `Anyone with ${HOST}/${account.handle} can see your loadout and its share card.`
              : 'Only you can see your loadout. Everyone else gets “not found”.'}
          </p>
        </div>
        <button
          type="button"
          role="switch"
          aria-checked={account.public}
          aria-label="Public profile"
          onClick={toggle}
          className={`relative h-7 w-12 shrink-0 rounded-full transition ${account.public ? 'bg-every-blue' : 'bg-rule'}`}
        >
          <span className={`absolute top-1 h-5 w-5 rounded-full bg-white shadow transition-all ${account.public ? 'left-6' : 'left-1'}`} />
        </button>
      </div>
    </Section>
  )
}

function DeleteSection({ account, error }: { account: Account; error?: string }) {
  const [confirmation, setConfirmation] = useState('')
  const expected = account.handle || 'delete'
  const matches = confirmation.trim().toLowerCase() === expected

  const destroy = (event: FormEvent) => {
    event.preventDefault()
    if (matches) router.delete('/settings', { data: { confirmation } })
  }

  return (
    <Section
      id="settings-delete"
      title="Delete account"
      description="Removes your profile, your loadout, and its history. This can’t be undone."
    >
      <form onSubmit={destroy} className="rounded-2xl border border-every-coral/40 bg-every-coral/5 p-5">
        <label htmlFor="settings-delete-input" className="text-sm text-ink-soft">
          Type <span className="font-mono font-medium text-ink">{expected}</span> to confirm.
        </label>
        <input
          id="settings-delete-input"
          value={confirmation}
          autoComplete="off"
          autoCapitalize="none"
          onChange={(event) => setConfirmation(event.target.value)}
          className="mt-3 block w-full rounded-xl border-rule bg-white px-3 py-2 font-mono text-sm focus:border-ink/40 focus:ring-0"
        />
        <FieldError message={error} />
        <button
          type="submit"
          disabled={!matches}
          className="mt-4 inline-flex items-center rounded-full bg-[#b4321f] px-4 py-2.5 text-sm font-medium text-white transition hover:bg-[#962817] disabled:opacity-40"
        >
          Delete my account
        </button>
      </form>
    </Section>
  )
}

export default function SettingsShow({ account, availability, errors = {} }: Props) {
  return (
    <AppShell>
      <Head title="Settings" />
      <div className="animate-rise">
        <p className="eyebrow">Settings</p>
        <h1 className="display mt-3 text-5xl text-ink sm:text-6xl">Your account</h1>
        <p className="mt-3 text-ink-muted">
          Signed in with Every as <span className="text-ink">{account.email}</span>
        </p>
      </div>

      <div className="mt-12">
        <HandleSection account={account} availability={availability} error={errors.handle} />
        <BioSection account={account} error={errors.bio} />
        <VisibilitySection account={account} />
        <Section id="settings-agents" title="Agents" description="Let an agent keep your loadout current over MCP. Revoke any of them any time.">
          <ConnectAgentCard compact />
        </Section>
        <DeleteSection account={account} error={errors.confirmation} />
      </div>
    </AppShell>
  )
}
