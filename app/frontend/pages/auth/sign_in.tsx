import { Head, Link, router, usePage } from '@inertiajs/react'
import { buttonClasses } from '../../components/button'
import Wordmark from '../../components/wordmark'
import type { FlashData } from '../../types'

export const EVERY_SIGN_IN_PATH = '/auth/every'

interface DevLoginPerson {
  email: string
  name: string | null
}

interface SignInProps {
  dev_login_people?: DevLoginPerson[]
}

interface SignInPageProps {
  flash: FlashData
  [key: string]: unknown
}

export default function SignIn({ dev_login_people }: SignInProps) {
  const { flash } = usePage<SignInPageProps>().props

  return (
    <>
      <Head title="Sign in" />
      <div className="flex min-h-screen flex-col">
        <header className="px-6 py-6 sm:px-10">
          <Link href="/" aria-label="Loadout home" className="text-ink">
            <Wordmark />
          </Link>
        </header>
        <main className="mx-auto flex w-full max-w-md flex-1 flex-col justify-center gap-8 px-6 pb-24">
          <div className="animate-rise">
            <p className="eyebrow">Sign in</p>
            <h1 className="display mt-3 text-5xl">Your AI loadout, in a minute.</h1>
            <p className="mt-4 text-lg text-ink-soft">
              Use your every.to account. You pick a link, tap the tools you use, and decide who sees it.
            </p>
          </div>

          {flash.alert && (
            <p role="alert" className="rounded-xl bg-every-coral/15 px-4 py-3 text-sm text-ink">
              {flash.alert}
            </p>
          )}

          {/* A full page navigation, not an Inertia visit: the OmniAuth middleware answers with a redirect to Every. */}
          <a href={EVERY_SIGN_IN_PATH} className={buttonClasses('primary', 'lg')}>
            Sign in with Every
          </a>
          <p className="-mt-4 text-center text-xs text-ink-muted">Profiles are private until you make them public.</p>

          {dev_login_people && (
            <section aria-labelledby="dev-login-heading" className="flex flex-col gap-2 border-t border-dashed border-rule pt-5">
              <h2 id="dev-login-heading" className="eyebrow">
                Dev login
              </h2>
              {dev_login_people.length === 0 ? (
                <p className="text-sm text-ink-muted">
                  No seeded people yet. Run <code>bin/rails db:seed</code>.
                </p>
              ) : (
                <ul className="grid grid-cols-2 gap-1.5">
                  {dev_login_people.map((person) => (
                    <li key={person.email}>
                      <button
                        type="button"
                        onClick={() => router.post('/dev/login', { email_address: person.email })}
                        className="w-full truncate rounded-full bg-white px-3 py-2 text-left text-sm text-ink ring-1 ring-rule hover:ring-ink/30"
                      >
                        Continue as {person.name ?? person.email}
                      </button>
                    </li>
                  ))}
                </ul>
              )}
            </section>
          )}
        </main>
      </div>
    </>
  )
}
