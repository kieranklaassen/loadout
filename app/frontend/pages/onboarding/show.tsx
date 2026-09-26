import { Head, router, usePage } from '@inertiajs/react'
import { useEffect, useState, type FormEvent, type ReactNode } from 'react'
import Button from '../../components/button'
import ToolMark from '../../components/tool_mark'
import ToolPicker from '../../components/tool_picker'
import Wordmark from '../../components/wordmark'
import { HOST, normalizeHandle } from '../../lib/handles'
import { changedCategories, countPicks, toOperations } from '../../lib/picks'
import type { FlashData, HandleAvailability, PickerData, PicksByCategory, SharedProps } from '../../types'

type Step = 'handle' | 'picks' | 'visibility'

type Props = {
  step: 'handle' | 'picks'
  handle: string | null
  suggested_handle: string
  first_name: string | null
  every_member: boolean
  public: boolean
  picker: PickerData
  availability?: HandleAvailability
  errors?: { handle?: string }
}

const STEPS: { key: Step; label: string }[] = [
  { key: 'handle', label: 'Claim' },
  { key: 'picks', label: 'Pick' },
  { key: 'visibility', label: 'Share' },
]

function Progress({ step }: { step: Step }) {
  const current = STEPS.findIndex((item) => item.key === step)
  return (
    <ol className="flex items-center gap-2 sm:gap-3" aria-label="Onboarding progress">
      {STEPS.map((item, index) => (
        <li key={item.key} className="flex items-center gap-2" aria-current={index === current ? 'step' : undefined}>
          <span
            className={`h-1.5 rounded-full transition-all duration-500 ${
              index < current ? 'w-6 bg-ink' : index === current ? 'w-10 bg-every-blue' : 'w-6 bg-rule'
            }`}
          />
          <span className={`hidden font-mono text-[0.7rem] uppercase tracking-wider sm:inline ${index === current ? 'text-ink' : 'text-ink-muted'}`}>
            {item.label}
          </span>
        </li>
      ))}
    </ol>
  )
}

function Frame({ step, children }: { step: Step; children: ReactNode }) {
  const { flash } = usePage<SharedProps>().props
  return (
    <div className="flex min-h-screen flex-col">
      <header className="mx-auto flex h-16 w-full max-w-6xl items-center justify-between px-5 sm:px-8">
        <Wordmark />
        <Progress step={step} />
      </header>
      {flash?.alert && (
        <div className="mx-auto w-full max-w-6xl px-5 sm:px-8">
          <p role="alert" className="rounded-xl bg-every-coral/15 px-4 py-3 text-sm text-ink">
            {flash.alert}
          </p>
        </div>
      )}
      <main className="mx-auto w-full max-w-6xl flex-1 px-5 pb-16 pt-8 sm:px-8 sm:pt-12">{children}</main>
    </div>
  )
}

function HandleStep({ props }: { props: Props }) {
  const initial = props.handle ?? props.suggested_handle
  const [value, setValue] = useState(initial)
  const [submitted, setSubmitted] = useState<string | null>(null)
  const [processing, setProcessing] = useState(false)
  const handle = normalizeHandle(value)

  useEffect(() => {
    if (!handle || handle === initial) return
    const timer = window.setTimeout(() => {
      router.get('/handles/check', { handle }, {
        only: ['availability'],
        preserveState: true,
        preserveScroll: true,
        preserveUrl: true,
        replace: true,
      })
    }, 220)
    return () => window.clearTimeout(timer)
  }, [handle, initial])

  const serverError = props.errors?.handle && (submitted === null || submitted === handle) ? props.errors.handle : null
  const checked = props.availability?.handle === handle ? props.availability : null
  const status: { tone: 'ok' | 'bad' | 'wait'; message: string } = !handle
    ? { tone: 'bad', message: 'Pick a handle.' }
    : serverError
      ? { tone: 'bad', message: serverError }
      : handle === initial
        ? { tone: 'ok', message: `${HOST}/${handle} is yours.` }
        : checked
          ? { tone: checked.available ? 'ok' : 'bad', message: checked.message }
          : { tone: 'wait', message: 'Checking…' }

  const submit = (event: FormEvent) => {
    event.preventDefault()
    if (status.tone !== 'ok') return
    setSubmitted(handle)
    router.patch('/welcome/handle', { handle }, {
      preserveState: 'errors',
      onStart: () => setProcessing(true),
      onFinish: () => setProcessing(false),
    })
  }

  return (
    <div className="mx-auto max-w-3xl animate-rise pt-6 sm:pt-16">
      <p className="eyebrow">Step 1 of 3{props.first_name ? ` · Hi, ${props.first_name}` : ''}</p>
      <h1 className="display mt-3 text-5xl text-ink sm:text-7xl">Claim your link.</h1>
      <p className="mt-4 max-w-xl text-lg text-ink-soft">This is where your loadout lives. Short and yours; you can change it later.</p>

      <form onSubmit={submit} className="mt-12">
        <label htmlFor="handle" className="eyebrow">
          Your link
        </label>
        <div className="mt-3 flex items-baseline border-b-2 border-ink pb-3 transition focus-within:border-every-blue">
          <span className="shrink-0 font-serif text-2xl text-ink-muted sm:text-5xl">{HOST}/</span>
          <input
            id="handle"
            name="handle"
            value={value}
            autoFocus
            autoCapitalize="none"
            autoCorrect="off"
            spellCheck={false}
            maxLength={30}
            onChange={(event) => setValue(event.target.value.toLowerCase().replace(/\s+/g, '-'))}
            aria-describedby="handle-status"
            aria-invalid={status.tone === 'bad'}
            className="min-w-0 flex-1 border-0 bg-transparent p-0 font-serif text-2xl text-ink focus:ring-0 sm:text-5xl"
          />
        </div>
        <p
          id="handle-status"
          aria-live="polite"
          className={`mt-3 flex items-center gap-2 text-sm ${status.tone === 'bad' ? 'text-[#b4321f]' : status.tone === 'ok' ? 'text-ink' : 'text-ink-muted'}`}
        >
          <span
            aria-hidden="true"
            className={`h-2 w-2 rounded-full ${status.tone === 'ok' ? 'bg-every-lime ring-2 ring-every-lime/40' : status.tone === 'bad' ? 'bg-every-coral' : 'animate-pulse bg-rule'}`}
          />
          {status.message}
        </p>

        <div className="mt-10 flex items-center gap-4">
          <Button type="submit" variant="blue" size="lg" disabled={status.tone !== 'ok' || processing}>
            Claim it <span aria-hidden="true">→</span>
          </Button>
          <span className="text-sm text-ink-muted">About a minute, start to finish.</span>
        </div>
      </form>
    </div>
  )
}

function PicksBar({ picks, saving, onBack, onContinue }: { picks: PicksByCategory; saving: boolean; onBack: () => void; onContinue: () => void }) {
  const counts = countPicks(picks)
  const tools = Object.values(picks).flat().map((pick) => pick.tool).slice(0, 5)

  return (
    <div className="sticky bottom-4 z-20 mt-8">
      <div className="mx-auto flex max-w-2xl items-center gap-3 rounded-full bg-ink py-2 pl-3 pr-2 text-paper shadow-[var(--shadow-lift)] sm:pl-4">
        <button type="button" onClick={onBack} className="rounded-full px-2 py-1 text-sm text-paper/60 hover:text-paper">
          Back
        </button>
        <div className="flex min-w-0 flex-1 items-center gap-2.5">
          {tools.length > 0 && (
            <span className="hidden -space-x-1.5 sm:flex">
              {tools.map((tool, i) => (
                <ToolMark key={`${tool.slug || tool.name}-${i}`} item={tool} size="sm" className="ring-2 ring-ink" />
              ))}
            </span>
          )}
          <span className="truncate text-sm text-paper/80" aria-live="polite">
            {counts.picks === 0
              ? 'Nothing picked yet'
              : `${counts.picks} ${counts.picks === 1 ? 'pick' : 'picks'} · ${counts.categories} ${counts.categories === 1 ? 'category' : 'categories'}`}
          </span>
        </div>
        <button
          type="button"
          onClick={onContinue}
          disabled={saving}
          className="inline-flex shrink-0 items-center gap-2 rounded-full bg-paper px-5 py-2.5 text-sm font-medium text-ink transition hover:bg-every-sky active:scale-[0.98] disabled:opacity-60"
        >
          {saving ? 'Saving…' : counts.picks === 0 ? 'Skip for now' : 'Continue'} <span aria-hidden="true">→</span>
        </button>
      </div>
    </div>
  )
}

function PicksStep({
  props,
  picks,
  setPicks,
  onDone,
  onAgent,
}: {
  props: Props
  picks: PicksByCategory
  setPicks: (picks: PicksByCategory) => void
  onDone: () => void
  onAgent: () => void
}) {
  const [saving, setSaving] = useState(false)
  const { picker } = props

  const save = () => {
    const changed = changedCategories(picker.picks, picks, picker.categories.map((category) => category.slug))
    if (changed.length === 0) return onDone()

    router.patch('/loadout', { operations: toOperations(picks, changed) }, {
      preserveState: true,
      preserveScroll: true,
      onStart: () => setSaving(true),
      onFinish: () => setSaving(false),
      onSuccess: (page) => {
        if (!(page.props.flash as FlashData | undefined)?.alert) onDone()
      },
    })
  }

  return (
    <div>
      <div className="grid animate-rise items-end gap-6 md:grid-cols-[1fr_auto]">
        <div>
          <p className="eyebrow">Step 2 of 3</p>
          <h1 className="display mt-3 text-5xl text-ink sm:text-6xl">What’s in your loadout?</h1>
          <p className="mt-4 max-w-xl text-lg text-ink-soft">
            Tap the tools you use. Add a model if you know it, star your go-to, and skip anything that isn’t you.
          </p>
        </div>
        <button
          type="button"
          onClick={onAgent}
          className="group flex items-center gap-3 rounded-2xl border border-rule bg-white px-4 py-3 text-left transition hover:border-ink/30"
        >
          <span className="flex h-9 w-9 items-center justify-center rounded-xl bg-ink font-mono text-xs text-paper">AI</span>
          <span>
            <span className="block text-sm font-medium text-ink">Rather let your agent do it?</span>
            <span className="block text-xs text-ink-muted">Connect Claude, Cursor or Codex instead</span>
          </span>
          <span aria-hidden="true" className="text-ink-muted transition group-hover:translate-x-0.5 group-hover:text-ink">
            →
          </span>
        </button>
      </div>

      <div className="mt-10">
        <ToolPicker categories={picker.categories} catalog={picker.catalog} value={picks} onChange={setPicks} />
      </div>

      <PicksBar picks={picks} saving={saving} onBack={() => router.get('/welcome', { step: 'handle' })} onContinue={save} />
    </div>
  )
}

function VisibilityOption({
  selected,
  onSelect,
  title,
  children,
  icon,
}: {
  selected: boolean
  onSelect: () => void
  title: string
  children: ReactNode
  icon: ReactNode
}) {
  return (
    <button
      type="button"
      role="radio"
      aria-checked={selected}
      onClick={onSelect}
      className={`relative flex h-full flex-col rounded-[var(--radius-card)] border bg-white p-6 text-left transition ${
        selected ? 'border-ink shadow-[var(--shadow-lift)]' : 'border-rule hover:border-ink/30'
      }`}
    >
      <span className="flex items-center justify-between">
        <span className={`flex h-10 w-10 items-center justify-center rounded-xl ${selected ? 'bg-ink text-paper' : 'bg-paper-deep text-ink'}`}>{icon}</span>
        <span className={`h-5 w-5 rounded-full border-2 transition ${selected ? 'border-every-blue bg-every-blue shadow-[inset_0_0_0_3px_white]' : 'border-rule'}`} />
      </span>
      <span className="display mt-5 text-3xl text-ink">{title}</span>
      <span className="mt-2 text-sm leading-relaxed text-ink-soft">{children}</span>
    </button>
  )
}

function VisibilityStep({ props, viaAgent, onBack }: { props: Props; viaAgent: boolean; onBack: () => void }) {
  const [isPublic, setIsPublic] = useState(props.public)
  const [processing, setProcessing] = useState(false)
  const handle = props.handle ?? props.suggested_handle

  const finish = () => {
    router.patch('/welcome/finish', { public: isPublic, next: viaAgent ? 'agents' : null }, {
      onStart: () => setProcessing(true),
      onFinish: () => setProcessing(false),
    })
  }

  return (
    <div className="mx-auto max-w-3xl animate-rise pt-6 sm:pt-12">
      <p className="eyebrow">Step 3 of 3</p>
      <h1 className="display mt-3 text-5xl text-ink sm:text-6xl">Who gets to see it?</h1>
      <p className="mt-4 max-w-xl text-lg text-ink-soft">Start private if you like. Switch any time in settings.</p>

      <div role="radiogroup" aria-label="Profile visibility" className="mt-10 grid gap-4 sm:grid-cols-2">
        <VisibilityOption
          selected={!isPublic}
          onSelect={() => setIsPublic(false)}
          title="Just me"
          icon={
            <svg viewBox="0 0 20 20" className="h-5 w-5" aria-hidden="true">
              <rect x="4" y="9" width="12" height="8" rx="2" fill="none" stroke="currentColor" strokeWidth="1.6" />
              <path d="M7 9V6.5a3 3 0 0 1 6 0V9" fill="none" stroke="currentColor" strokeWidth="1.6" />
            </svg>
          }
        >
          Private. Your page answers “not found” to everyone else.
          {props.every_member && ' Your picks still count, anonymously, in the Every map totals.'}
        </VisibilityOption>
        <VisibilityOption
          selected={isPublic}
          onSelect={() => setIsPublic(true)}
          title="Anyone with the link"
          icon={
            <svg viewBox="0 0 20 20" className="h-5 w-5" aria-hidden="true">
              <circle cx="10" cy="10" r="7" fill="none" stroke="currentColor" strokeWidth="1.6" />
              <path d="M3 10h14M10 3c2.2 2.3 2.2 11.7 0 14M10 3c-2.2 2.3-2.2 11.7 0 14" fill="none" stroke="currentColor" strokeWidth="1.3" />
            </svg>
          }
        >
          Public at <span className="font-mono text-[0.8rem] text-ink">{HOST}/{handle}</span>, with a share card that unfurls nicely in Slack and X.
          {props.every_member && ' You’ll be named on the Every map.'}
        </VisibilityOption>
      </div>

      <div className="mt-10 flex flex-wrap items-center gap-4">
        <Button variant="blue" size="lg" onClick={finish} disabled={processing}>
          {viaAgent ? 'Finish and connect your agent' : 'Finish and see my loadout'} <span aria-hidden="true">→</span>
        </Button>
        <button type="button" onClick={onBack} className="text-sm text-ink-muted underline decoration-rule underline-offset-4 hover:text-ink">
          Back to picks
        </button>
      </div>
    </div>
  )
}

export default function OnboardingShow(props: Props) {
  const [step, setStep] = useState<Step>(props.step)
  const [viaAgent, setViaAgent] = useState(false)
  const [picks, setPicks] = useState<PicksByCategory>(props.picker.picks)

  const go = (next: Step) => {
    setStep(next)
    window.scrollTo({ top: 0 })
  }

  return (
    <Frame step={step}>
      <Head title="Welcome" />
      {step === 'handle' && <HandleStep props={props} />}
      {step === 'picks' && (
        <PicksStep
          props={props}
          picks={picks}
          setPicks={setPicks}
          onDone={() => {
            setViaAgent(false)
            go('visibility')
          }}
          onAgent={() => {
            setViaAgent(true)
            go('visibility')
          }}
        />
      )}
      {step === 'visibility' && <VisibilityStep props={props} viaAgent={viaAgent} onBack={() => go('picks')} />}
    </Frame>
  )
}
