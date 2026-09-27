import { Head, Link, router } from '@inertiajs/react'
import AppShell from '../../components/app_shell'
import { buttonClasses } from '../../components/button'
import { sectionLabelClasses } from '../../components/section_label'
import collage from '../../assets/every-collage.jpg'

export const EVERY_SIGN_IN_PATH = '/auth/every'

interface DevLoginPerson {
  email: string
  name: string | null
}

interface SignInProps {
  join_every_url: string
  /** Only sent in development. */
  dev_login_people?: DevLoginPerson[]
}

export default function SignIn({ join_every_url, dev_login_people }: SignInProps) {
  return (
    <AppShell header="logo">
      <Head title="Sign in" />
      <div className="grid grid-cols-1 gap-10 pt-4 md:grid-cols-[minmax(0,1fr)_480px] md:gap-[72px] md:pt-10">
        <div className="md:pt-10">
          <h1 className="display text-[44px] md:text-[64px]">
            Sign in with <span className="italic text-sky">Every</span>
          </h1>
          <p className="mt-5 max-w-[520px] text-lg leading-normal text-fg-soft">
            Members of the Every team and Every subscribers can sign in to rank their AI tools. Everyone else can still read the team’s
            public page.
          </p>

          {/* A full page navigation, not an Inertia visit: the OmniAuth middleware answers with a redirect to Every. */}
          <a href={EVERY_SIGN_IN_PATH} className={`${buttonClasses('primary', 'lg')} mt-9`}>
            Sign in with Every
          </a>
          <p className="mt-5 max-w-[460px] text-sm leading-normal text-fg-soft">
            We read your name, photo and email from your Every account. Your loadout stays private until you choose who can see it.
          </p>
          <p className="mt-7 text-sm text-fg-soft">
            Not on Every yet?{' '}
            <a href={join_every_url} className="text-link">
              Join Every
            </a>{' '}
            or{' '}
            <Link href="/" className="text-link">
              read the team’s page
            </Link>
          </p>

          {dev_login_people && (
            <section aria-labelledby="dev-login-heading" className="mt-10 flex max-w-[520px] flex-col gap-3 border-t border-dashed border-line-strong pt-5">
              <h2 id="dev-login-heading" className={sectionLabelClasses}>
                Dev login
              </h2>
              {dev_login_people.length === 0 ? (
                <p className="text-sm text-fg-muted">
                  No seeded people yet. Run <code>bin/rails db:seed</code>.
                </p>
              ) : (
                <ul className="grid grid-cols-1 gap-2 sm:grid-cols-2">
                  {dev_login_people.map((person) => (
                    <li key={person.email}>
                      <button
                        type="button"
                        onClick={() => router.post('/dev/login', { email_address: person.email })}
                        className="min-h-11 w-full truncate rounded-sharp border border-line bg-panel px-3 py-2 text-left text-sm text-fg hover:border-line-strong md:min-h-0"
                      >
                        Continue as {person.name ?? person.email}
                      </button>
                    </li>
                  ))}
                </ul>
              )}
            </section>
          )}
        </div>

        <div aria-hidden="true" className="relative hidden h-[480px] w-[480px] flex-none overflow-hidden bg-yellow md:block">
          <img src={collage} alt="" loading="lazy" className="absolute -left-[26px] top-0 w-[860px] max-w-none" />
        </div>
      </div>
    </AppShell>
  )
}
