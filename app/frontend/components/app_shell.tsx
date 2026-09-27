import { Link, router, usePage } from '@inertiajs/react'
import { useEffect, useRef, useState, type ReactNode } from 'react'
import type { SharedProps } from '../types'
import Avatar from './avatar'
import { ButtonLink } from './button'
import Wordmark from './wordmark'

function NavLink({ href, children, active }: { href: string; children: ReactNode; active: boolean }) {
  return (
    <Link
      href={href}
      className={`whitespace-nowrap rounded-full px-3 py-1.5 text-sm transition ${active ? 'bg-ink text-paper' : 'text-ink-soft hover:bg-ink/5 hover:text-ink'}`}
    >
      {children}
    </Link>
  )
}

function AccountMenu() {
  const { current_user } = usePage<SharedProps>().props
  const [open, setOpen] = useState(false)
  const ref = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (!open) return
    const close = (event: MouseEvent) => {
      if (!ref.current?.contains(event.target as Node)) setOpen(false)
    }
    document.addEventListener('mousedown', close)
    return () => document.removeEventListener('mousedown', close)
  }, [open])

  if (!current_user) return null

  const item = 'block w-full rounded-lg px-3 py-2 text-left text-sm text-ink-soft hover:bg-paper-deep hover:text-ink'

  return (
    <div ref={ref} className="relative">
      <button
        type="button"
        aria-haspopup="menu"
        aria-expanded={open}
        aria-label="Account menu"
        onClick={() => setOpen((value) => !value)}
        className="rounded-full"
      >
        <Avatar name={current_user.name} src={current_user.avatar_url} size="sm" />
      </button>
      {open && (
        <div role="menu" className="card absolute right-0 z-30 mt-2 w-56 p-1.5">
          <p className="px-3 pb-2 pt-1.5 text-xs text-ink-muted">
            Signed in as <span className="font-medium text-ink">{current_user.name}</span>
          </p>
          {current_user.handle && (
            <Link href={`/${current_user.handle}`} className={item} role="menuitem">
              Your profile
            </Link>
          )}
          <Link href="/loadout/edit" className={item} role="menuitem">
            Edit loadout
          </Link>
          <Link href="/agents" className={item} role="menuitem">
            Connected agents
          </Link>
          <Link href="/settings" className={item} role="menuitem">
            Settings
          </Link>
          {current_user.admin && (
            <Link href="/admin/catalog_items" className={item} role="menuitem">
              Catalog review
            </Link>
          )}
          <button type="button" className={item} role="menuitem" onClick={() => router.delete('/session')}>
            Sign out
          </button>
        </div>
      )}
    </div>
  )
}

export default function AppShell({ children, wide = false }: { children: ReactNode; wide?: boolean }) {
  const { current_user, flash } = usePage<SharedProps>().props
  const path = typeof window === 'undefined' ? '' : window.location.pathname
  const width = wide ? 'max-w-6xl' : 'max-w-5xl'

  return (
    <div className="flex min-h-screen flex-col">
      <header className="sticky top-0 z-20 border-b border-rule/70 bg-paper/85 backdrop-blur">
        <div className={`mx-auto flex h-16 items-center justify-between gap-4 px-5 sm:px-8 ${width}`}>
          <Link href="/" aria-label="Loadout home" className="text-ink">
            <Wordmark />
          </Link>
          <nav className="flex items-center gap-1 sm:gap-2">
            {current_user?.every_member && (
              <NavLink href="/map" active={path.startsWith('/map')}>
                Every map
              </NavLink>
            )}
            {current_user?.handle && (
              <NavLink href={`/${current_user.handle}`} active={path === `/${current_user.handle}`}>
                Your loadout
              </NavLink>
            )}
            {current_user ? (
              <AccountMenu />
            ) : (
              <ButtonLink href="/session/new" variant="primary">
                Sign in
              </ButtonLink>
            )}
          </nav>
        </div>
      </header>

      {(flash?.notice || flash?.alert) && (
        <div className={`mx-auto w-full px-5 pt-4 sm:px-8 ${width}`}>
          <p
            role={flash.alert ? 'alert' : 'status'}
            className={`rounded-xl px-4 py-3 text-sm ${flash.alert ? 'bg-every-coral/15 text-ink' : 'bg-every-sky/60 text-ink'}`}
          >
            {flash.alert ?? flash.notice}
          </p>
        </div>
      )}

      <main className={`mx-auto w-full flex-1 px-5 py-10 sm:px-8 sm:py-14 ${width}`}>{children}</main>

      <footer className="border-t border-rule/70">
        <div className={`mx-auto flex flex-col gap-2 px-5 py-8 text-sm text-ink-muted sm:flex-row sm:items-center sm:justify-between sm:px-8 ${width}`}>
          <span>
            Loadout is made at{' '}
            <a href="https://every.to" className="underline decoration-rule underline-offset-4 hover:text-ink">
              Every
            </a>
            .
          </span>
          <span className="font-mono text-xs">What's in your AI loadout?</span>
        </div>
      </footer>
    </div>
  )
}
