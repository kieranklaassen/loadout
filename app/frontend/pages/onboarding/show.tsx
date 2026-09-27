import { Head, router } from '@inertiajs/react'
import { useState, type FormEvent } from 'react'
import AppShell from '../../components/app_shell'
import Avatar from '../../components/avatar'
import Button from '../../components/button'
import HandleField, { useHandleStatus } from '../../components/handle_field'
import SectionLabel from '../../components/section_label'
import VisibilityChoice from '../../components/visibility_choice'
import { fieldErrors } from '../../lib/field_errors'
import { usePublicHost } from '../../lib/public_host'
import { VISIBILITY_STATUS } from '../../lib/visibility_copy'
import type { HandleAvailability, Visibility } from '../../types'

type Props = {
  /** The handle to start from: the member's own, or a free one made from their name. */
  suggested_handle: string
  name: string
  avatar_url: string | null
  visibility: Visibility
  /** Two real kinds of work, for the preview's empty rows. */
  preview_kinds: string[]
  availability?: HandleAvailability
}

function Preview({ name, avatarUrl, handle, kinds, visibility }: { name: string; avatarUrl: string | null; handle: string; kinds: string[]; visibility: Visibility }) {
  const host = usePublicHost()

  return (
    <div>
      <SectionLabel as="p">Preview</SectionLabel>
      <div className="panel mt-3 p-5 md:p-7">
        <div className="flex items-center gap-4">
          <Avatar name={name} src={avatarUrl} size="lg" />
          <div className="min-w-0">
            <p className="display break-words text-[28px] md:text-[32px]">{name}</p>
            <p className="mt-1 break-all font-mono text-caption text-fg-muted">
              {host}/{handle}
            </p>
          </div>
        </div>
        <div className="mt-5 border-t border-line">
          {kinds.map((kind) => (
            <div key={kind} className="flex items-center gap-3.5 border-b border-line py-3">
              <span className="w-28 shrink-0 font-serif text-[17px] text-fg-soft md:w-32">{kind}</span>
              <span className="flex h-9 flex-1 items-center rounded-sharp border border-dashed border-line-strong px-3 text-caption text-fg-muted">
                Empty
              </span>
            </div>
          ))}
        </div>
        <p aria-live="polite" className="mt-3.5 text-caption text-fg-muted">
          {VISIBILITY_STATUS[visibility]}
        </p>
      </div>
    </div>
  )
}

/** Claim your link: a handle and who can see the page, then on to ranking the first tools. */
export default function OnboardingShow({ suggested_handle, name, avatar_url, visibility, preview_kinds, availability }: Props) {
  const [value, setValue] = useState(suggested_handle)
  const [level, setLevel] = useState<Visibility>(visibility)
  const [errors, setErrors] = useState<Record<string, string>>({})
  const [processing, setProcessing] = useState(false)
  const { handle, status } = useHandleStatus({ value, initial: suggested_handle, availability, error: errors.handle })

  const submit = (event: FormEvent) => {
    event.preventDefault()
    if (status.tone !== 'ok' || processing) return
    router.patch('/welcome', { handle, visibility: level }, {
      preserveState: true,
      onStart: () => {
        setProcessing(true)
        setErrors({})
      },
      onFinish: () => setProcessing(false),
      onError: (next) => setErrors(fieldErrors(next)),
    })
  }

  return (
    <AppShell header="account">
      <Head title="Claim your link" />
      <div className="grid grid-cols-1 gap-12 pt-4 md:grid-cols-[minmax(0,1fr)_minmax(0,520px)] md:gap-[72px] md:pt-8">
        <div>
          <SectionLabel as="p">Step 1 of 2 · Then rank your first tools</SectionLabel>
          <h1 className="display mt-3.5 text-[40px] md:text-[56px]">Claim your link</h1>
          <p className="mt-4 max-w-[520px] text-lg leading-normal text-fg-soft">
            This is the address of your loadout. You can change it later in settings.
          </p>

          <form onSubmit={submit} className="mt-8">
            <HandleField
              value={value}
              onChange={(next) => {
                setValue(next)
                setErrors({})
              }}
              status={status}
              autoFocus
            />

            <h2 id="visibility-heading" className="mt-8 text-sm font-semibold text-fg">
              Who can see it
            </h2>
            <div className="mt-2.5 max-w-[560px]">
              <VisibilityChoice value={level} onChange={setLevel} labelledBy="visibility-heading" error={errors.visibility} />
            </div>

            <Button type="submit" size="lg" className="mt-6" disabled={status.tone !== 'ok' || processing}>
              Save and rank my first tools
            </Button>
          </form>
        </div>

        <Preview name={name} avatarUrl={avatar_url} handle={handle} kinds={preview_kinds} visibility={level} />
      </div>
    </AppShell>
  )
}
