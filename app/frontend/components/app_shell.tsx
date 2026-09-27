import { Link, router, usePage } from '@inertiajs/react'
import { useEffect, useRef, useState, type ReactNode } from 'react'
import { usePublicHost } from '../lib/public_host'
import type { SharedProps } from '../types'
import Avatar from './avatar'
import { ButtonLink } from './button'
import Wordmark from './wordmark'

const CONTAINER = 'mx-auto w-full max-w-[1440px] px-4 md:px-8 lg:px-22'

const NAV = [
  { label: 'Home', href: '/', active: (path: string) => path === '/' || path.startsWith('/kinds') },
  { label: 'Your loadout', href: '/loadout/edit', active: (path: string) => path.startsWith('/loadout') },
  { label: 'Agents', href: '/agents', active: (path: string) => path.startsWith('/agents') },
  { label: 'Settings', href: '/settings', active: (path: string) => path.startsWith('/settings') },
]

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

  const item = 'block min-h-11 w-full rounded-sharp px-3 py-2.5 text-left text-sm text-fg-soft hover:bg-raised hover:text-fg md:min-h-0'

  return (
    <div ref={ref} className="relative">
      <button
        type="button"
        aria-haspopup="menu"
        aria-expanded={open}
        aria-label="Account menu"
        onClick={() => setOpen((value) => !value)}
        className="rounded-soft"
      >
        <Avatar name={current_user.name} src={current_user.avatar_url} size="md" />
      </button>
      {open && (
        <div role="menu" className="panel absolute right-0 z-30 mt-2 w-56 p-1.5">
          <p className="px-3 pb-2 pt-1.5 text-caption text-fg-muted">
            Signed in as <span className="font-medium text-fg">{current_user.name}</span>
          </p>
          {current_user.handle && (
            <Link href={`/${current_user.handle}`} className={item} role="menuitem">
              Your profile
            </Link>
          )}
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

type Header = 'full' | 'account' | 'logo'

/**
 * The page frame: header, flash message, content and footer lockup. `search` is the
 * Home header's search slot. `header` trims the chrome for the pages that have no
 * navigation yet: 'account' is the logo and account only, 'logo' the logo alone.
 */
export default function AppShell({
  children,
  search,
  header = 'full',
}: {
  children: ReactNode
  search?: ReactNode
  header?: Header
  /** Ignored: v1 pages still pass it until U13 removes them. */
  wide?: boolean
}) {
  const { props, url } = usePage<SharedProps>()
  const { current_user, flash } = props
  const host = usePublicHost()
  const path = (url ?? '').split('?')[0]
  const [menuOpen, setMenuOpen] = useState(false)

  const showNav = header === 'full' && Boolean(current_user)
  const showSearch = header === 'full' && Boolean(search)

  return (
    <div className="flex min-h-screen flex-col">
      <header className="relative z-20">
        <div className={`${CONTAINER} flex flex-wrap items-center justify-between gap-x-6 gap-y-2 py-5 md:flex-nowrap md:py-6`}>
          <Link href="/" aria-label="Every Loadout home">
            <Wordmark />
          </Link>

          {/* Below 768px this panel opens from the Menu button; from 768px its children join the header row. */}
          {(showNav || showSearch) && (
            <div id="site-menu" className={`${menuOpen ? 'flex' : 'hidden'} order-last w-full flex-col gap-2 md:contents`}>
              {showSearch && <div className="md:max-w-[460px] md:flex-1">{search}</div>}
              {showNav && (
                <nav aria-label="Main" className="flex flex-col md:flex-row md:gap-8">
                  {NAV.map(({ label, href, active }) => {
                    const current = active(path)
                    return (
                      <Link
                        key={href}
                        href={href}
                        aria-current={current ? 'page' : undefined}
                        className={`flex min-h-11 items-center border-b-2 text-[15px] md:min-h-0 md:pb-1 ${current ? 'border-sky text-fg' : 'border-transparent text-fg-muted hover:text-fg'}`}
                      >
                        {label}
                      </Link>
                    )
                  })}
                </nav>
              )}
            </div>
          )}

          <div className="flex items-center gap-3">
            {(showNav || showSearch) && (
              <button
                type="button"
                aria-expanded={menuOpen}
                aria-controls="site-menu"
                onClick={() => setMenuOpen((value) => !value)}
                className="min-h-11 rounded-sharp border border-line px-3 text-sm text-fg-soft hover:border-line-strong md:hidden"
              >
                Menu
              </button>
            )}
            {header !== 'logo' &&
              (current_user ? (
                <AccountMenu />
              ) : (
                <ButtonLink href="/session/new" variant="primary">
                  Sign in
                </ButtonLink>
              ))}
          </div>
        </div>
      </header>

      {(flash?.notice || flash?.alert) && (
        <div className={`${CONTAINER} pt-2`}>
          <p
            role={flash.alert ? 'alert' : 'status'}
            className={`rounded-soft border px-4 py-3 text-sm ${flash.alert ? 'border-coral/50 text-coral' : 'panel text-fg'}`}
          >
            {flash.alert ?? flash.notice}
          </p>
        </div>
      )}

      <main className={`${CONTAINER} flex-1 pb-16 pt-6 md:pb-20`}>{children}</main>

      <footer className={CONTAINER}>
        <div className="flex flex-col gap-3 border-t border-line py-6 md:flex-row md:items-center md:justify-between">
          <div className="flex flex-wrap items-center gap-x-3 gap-y-1 text-sm text-fg-muted">
            <Wordmark size="sm" />
            <span className="font-mono text-caption">{host}</span>
          </div>
          <span className="font-mono text-caption text-fg-muted">Private by default. Public when you want.</span>
        </div>
      </footer>
    </div>
  )
}
