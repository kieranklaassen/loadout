import { router } from '@inertiajs/react'
import { useEffect, useRef, useState, type FormEvent } from 'react'
import type { Catalog } from '../../lib/ranking'
import type { CatalogKind } from '../../types'
import Button from '../button'
import { sectionLabelClasses } from '../section_label'

const NAME_LENGTH = { min: 2, max: 60 }
const REFUSED = 'That did not add. Try again.'

const squish = (value: string) => value.trim().replace(/\s+/g, ' ')

/** "Can't find one? Add a tool or model": a new name becomes a pending catalog item that shows up in the lists for the member. It is never picked for them. */
export default function AddItem({ catalog }: { catalog: Catalog }) {
  const [open, setOpen] = useState(false)
  const [kind, setKind] = useState<CatalogKind>('tool')
  const [name, setName] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [added, setAdded] = useState<string | null>(null)
  const [sending, setSending] = useState(false)
  const trigger = useRef<HTMLButtonElement>(null)
  const input = useRef<HTMLInputElement>(null)

  useEffect(() => {
    if (open) input.current?.focus()
  }, [open])

  const clean = squish(name)
  const listed = (kind === 'tool' ? catalog.tools : catalog.models).some((item) => item.name.toLowerCase() === clean.toLowerCase())
  const message = listed ? 'Already in the list' : error

  const submit = (event: FormEvent) => {
    event.preventDefault()
    if (listed || sending) return
    if (clean.length < NAME_LENGTH.min || clean.length > NAME_LENGTH.max) {
      return setError(`Use ${NAME_LENGTH.min} to ${NAME_LENGTH.max} characters.`)
    }

    setError(null)
    setSending(true)
    router.post(
      '/toolbox/catalog_items',
      { kind, name: clean },
      {
        preserveScroll: true,
        preserveState: true,
        onSuccess: () => {
          setAdded(clean)
          setName('')
          setOpen(false)
          trigger.current?.focus()
        },
        onError: (errors) => setError(String(Object.values(errors)[0] ?? REFUSED)),
        onNetworkError: () => setError(REFUSED),
        onHttpException: () => setError(REFUSED),
        onFinish: () => setSending(false),
      },
    )
  }

  return (
    <div className="mt-10">
      <p className="text-caption text-fg-muted">
        Can’t find one?{' '}
        <button
          ref={trigger}
          type="button"
          className="text-link"
          aria-expanded={open}
          aria-controls="add-item-form"
          onClick={() => {
            setAdded(null)
            setOpen((value) => !value)
          }}
        >
          Add a tool or model
        </button>
        . It shows up for you right away and an admin reviews it.
      </p>

      {added && (
        <p role="status" className="mt-3 text-caption text-fg-soft">
          Added {added}. It is in the lists as pending review; pick it where you want it.
        </p>
      )}

      {open && (
        <form id="add-item-form" noValidate onSubmit={submit} className="panel mt-4 max-w-xl space-y-4 p-4 md:p-5">
          <fieldset>
            <legend className={`${sectionLabelClasses} mb-2`}>What is it?</legend>
            <div className="grid grid-cols-2 gap-2">
              {(['tool', 'model'] as const).map((value) => (
                <label key={value} className="radio-card items-center">
                  <input type="radio" name="item-kind" checked={kind === value} onChange={() => setKind(value)} />
                  <span className="radio-dot mt-0" />
                  <span className="text-[15px]">{value === 'tool' ? 'Tool' : 'Model'}</span>
                </label>
              ))}
            </div>
          </fieldset>

          <div>
            <label htmlFor="add-item-name" className={`${sectionLabelClasses} mb-1.5 block`}>
              Name
            </label>
            <div className="field-box">
              <input
                ref={input}
                id="add-item-name"
                value={name}
                aria-invalid={message ? true : undefined}
                aria-describedby={message ? 'add-item-message' : undefined}
                onChange={(event) => {
                  setName(event.target.value)
                  setError(null)
                }}
              />
            </div>
            {message && (
              <p id="add-item-message" role={listed ? 'status' : 'alert'} className={`mt-2 text-caption ${listed ? 'text-fg-soft' : 'text-coral'}`}>
                {message}
              </p>
            )}
          </div>

          <p className="text-caption text-fg-muted">An admin reviews new items before the team sees them.</p>
          <div className="flex gap-2">
            <Button type="submit" disabled={listed} aria-disabled={sending || undefined}>
              Add
            </Button>
            <Button variant="secondary" onClick={() => setOpen(false)}>
              Cancel
            </Button>
          </div>
        </form>
      )}
    </div>
  )
}
