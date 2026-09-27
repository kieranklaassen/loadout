import { router } from '@inertiajs/react'
import { useEffect, type ReactNode } from 'react'
import { normalizeHandle } from '../lib/handles'
import { usePublicHost } from '../lib/public_host'
import type { HandleAvailability } from '../types'

export type HandleStatus = { tone: 'ok' | 'bad' | 'wait'; message: string }

function describeHandle({
  handle,
  initial,
  host,
  error,
  checked,
}: {
  handle: string
  initial: string
  host: string
  error?: string
  checked: HandleAvailability | null
}): HandleStatus {
  if (!handle) return { tone: 'bad', message: 'Pick a handle.' }
  if (error) return { tone: 'bad', message: error }
  if (handle === initial) return { tone: 'ok', message: `${host}/${handle} is yours.` }
  if (checked) return { tone: checked.available ? 'ok' : 'bad', message: checked.message }
  return { tone: 'wait', message: 'Checking…' }
}

/**
 * The live answer for a handle being typed: yours as it stands, or checked against the
 * server through a partial reload of /handles/check (the answer arrives as the page's
 * `availability` prop). `error` is a server refusal of this very value and wins over it.
 */
export function useHandleStatus({
  value,
  initial,
  availability,
  error,
}: {
  value: string
  initial: string
  availability?: HandleAvailability
  error?: string
}): { handle: string; status: HandleStatus } {
  const host = usePublicHost()
  const handle = normalizeHandle(value)

  useEffect(() => {
    if (!handle || handle === initial) return
    const timer = window.setTimeout(() => {
      router.get('/handles/check', { handle }, { only: ['availability'], preserveState: true, preserveScroll: true, preserveUrl: true, replace: true })
    }, 220)
    return () => window.clearTimeout(timer)
  }, [handle, initial])

  const checked = availability?.handle === handle ? availability : null

  return { handle, status: describeHandle({ handle, initial, host, error, checked }) }
}

const TONE: Record<HandleStatus['tone'], string> = { ok: 'text-fg', bad: 'text-coral', wait: 'text-fg-muted' }

/** "Your link": the host, then the handle to type, with the live answer under it. */
export default function HandleField({
  value,
  onChange,
  status,
  autoFocus = false,
  className = 'max-w-[560px]',
  children,
}: {
  value: string
  onChange: (value: string) => void
  status: HandleStatus
  autoFocus?: boolean
  /** The width of the field, so it lines up with the fields around it. */
  className?: string
  /** A hint that stays under the answer. */
  children?: ReactNode
}) {
  const host = usePublicHost()

  return (
    <div className={className}>
      <label htmlFor="handle" className="block text-sm font-semibold text-fg">
        Your link
      </label>
      <span className="field-box mt-2 gap-0 py-3 font-mono text-base">
        <span className="shrink-0 text-fg-muted">{host}/</span>
        <input
          id="handle"
          name="handle"
          value={value}
          autoFocus={autoFocus}
          autoComplete="off"
          autoCapitalize="none"
          autoCorrect="off"
          spellCheck={false}
          maxLength={30}
          onChange={(event) => onChange(event.target.value.toLowerCase().replace(/\s+/g, '-'))}
          aria-describedby="handle-status"
          aria-invalid={status.tone === 'bad'}
        />
      </span>
      <p id="handle-status" aria-live="polite" className={`mt-2 flex items-start gap-2 text-sm ${TONE[status.tone]}`}>
        {status.tone === 'ok' && <span aria-hidden="true">✓</span>}
        <span className="min-w-0 break-words">{status.message}</span>
      </p>
      {children && <p className="mt-1.5 text-caption text-fg-muted">{children}</p>}
    </div>
  )
}
