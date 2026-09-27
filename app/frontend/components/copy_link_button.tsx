import { useEffect, useState } from 'react'
import { buttonClasses } from './button'

async function copyText(value: string) {
  if (navigator.clipboard?.writeText) {
    await navigator.clipboard.writeText(value)
    return
  }
  const field = document.createElement('textarea')
  field.value = value
  field.setAttribute('readonly', '')
  field.style.position = 'fixed'
  field.style.opacity = '0'
  document.body.appendChild(field)
  field.select()
  document.execCommand('copy')
  field.remove()
}

function LinkIcon() {
  return (
    <svg viewBox="0 0 20 20" className="h-4 w-4" aria-hidden="true" fill="none" stroke="currentColor" strokeWidth="1.6">
      <path d="M8.5 11.5a3.5 3.5 0 0 0 5 0l2.5-2.5a3.5 3.5 0 0 0-5-5L10 5" strokeLinecap="round" />
      <path d="M11.5 8.5a3.5 3.5 0 0 0-5 0L4 11a3.5 3.5 0 0 0 5 5l1-1" strokeLinecap="round" />
    </svg>
  )
}

function CheckIcon() {
  return (
    <svg viewBox="0 0 20 20" className="h-4 w-4" aria-hidden="true" fill="none" stroke="currentColor" strokeWidth="1.8">
      <path d="m4.5 10.5 3.5 3.5 7.5-8" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  )
}

/** The Copy link button: copies the URL and says so for two seconds. */
export function CopyLinkButton({ url }: { url: string }) {
  const [copied, setCopied] = useState(false)

  useEffect(() => {
    if (!copied) return
    const timer = window.setTimeout(() => setCopied(false), 2000)
    return () => window.clearTimeout(timer)
  }, [copied])

  const copy = async () => {
    try {
      await copyText(url)
      setCopied(true)
    } catch {
      setCopied(false)
    }
  }

  return (
    <>
      <button type="button" onClick={copy} className={`${buttonClasses('primary')} min-w-[8.5rem]`}>
        {copied ? <CheckIcon /> : <LinkIcon />}
        <span>{copied ? 'Link copied' : 'Copy link'}</span>
      </button>
      <span role="status" aria-live="polite" className="sr-only">
        {copied ? 'Link copied to clipboard' : ''}
      </span>
    </>
  )
}
