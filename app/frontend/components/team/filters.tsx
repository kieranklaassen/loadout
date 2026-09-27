import { Link, router } from '@inertiajs/react'
import SectionLabel from '../section_label'

export type Show = 'team' | 'others'

export type HomeFilters = {
  show: Show
  person: string | null
  overall: boolean
  q: string | null
}

export type PersonOption = { handle: string; name: string }

const SHOWS: { value: Show | 'subscribers'; label: string }[] = [
  { value: 'team', label: 'Every team' },
  { value: 'others', label: 'Everyone else' },
  { value: 'subscribers', label: 'Every subscribers' },
]

/** The query string Home reads. Defaults (Every team, everyone, kind of work) are left out. */
export function homeParams({ show, person, overall }: Partial<HomeFilters>) {
  return {
    ...(show && show !== 'team' && { show }),
    ...(person && { person }),
    ...(overall && { overall: '1' }),
  }
}

export function homeHref(filters: Partial<HomeFilters>) {
  const query = new URLSearchParams(homeParams(filters)).toString()
  return query ? `/?${query}` : '/'
}

/** The kind page for a row or a search hit, keeping the group being shown so its counts match Home's. */
export const kindHref = (slug: string, show: Show) => `/kinds/${slug}${show === 'team' ? '' : `?show=${show}`}`

const visit = (filters: Partial<HomeFilters>) => router.get('/', homeParams(filters), { preserveScroll: true, preserveState: true })

const chip = 'inline-flex min-h-11 items-center gap-2 rounded-sharp px-3.5 py-2 text-sm ring-1 ring-inset md:min-h-0'
const chipState =
  'has-[input:checked]:bg-sky has-[input:checked]:font-semibold has-[input:checked]:text-on-light has-[input:checked]:ring-sky has-[input:focus-visible]:outline-2 has-[input:focus-visible]:outline-offset-3 has-[input:focus-visible]:outline-sky'

/**
 * SHOW and PERSON. Each is a normal Inertia visit. A person belongs to exactly one SHOW
 * group, so changing SHOW always drops the selected person.
 */
export default function Filters({ filters, people }: { filters: HomeFilters; people: PersonOption[] }) {
  const { show, person, overall } = filters

  return (
    <div className="flex flex-col gap-3 md:flex-row md:flex-wrap md:items-center md:gap-x-6">
      <div role="radiogroup" aria-label="Show" className="flex flex-wrap items-center gap-2">
        <SectionLabel className="mr-1">Show</SectionLabel>
        {SHOWS.map((option) => {
          const soon = option.value === 'subscribers'
          return (
            <label
              key={option.value}
              className={`${chip} ${chipState} ${soon ? 'cursor-not-allowed text-fg-muted ring-line' : 'cursor-pointer text-fg-soft ring-line-strong hover:text-fg'}`}
            >
              <input
                type="radio"
                name="show"
                value={option.value}
                className="sr-only"
                checked={show === option.value}
                disabled={soon}
                aria-disabled={soon || undefined}
                onChange={() => visit({ show: option.value as Show, overall })}
              />
              {option.label}
              {soon && <span className="text-caption">Coming soon</span>}
            </label>
          )
        })}
      </div>

      <div className="field-box min-h-11 md:min-h-0 md:w-64">
        <SectionLabel as="label" htmlFor="home-person">
          Person
        </SectionLabel>
        <select id="home-person" value={person ?? ''} onChange={(event) => visit({ show, person: event.target.value || null })}>
          <option value="">All of us</option>
          {people.map((option) => (
            <option key={option.handle} value={option.handle}>
              {option.name}
            </option>
          ))}
        </select>
        <span aria-hidden="true" className="text-fg-muted">
          ▾
        </span>
      </div>
    </div>
  )
}

/** By kind of work / Overall top 10: two links, the current one marked. */
export function ViewToggle({ filters }: { filters: HomeFilters }) {
  const { show, overall } = filters
  const link = 'inline-flex min-h-11 items-center px-4 py-2 text-sm md:min-h-0'
  const current = 'bg-sky font-semibold text-on-light'
  const other = 'text-fg-soft ring-1 ring-inset ring-line hover:text-fg'

  return (
    <nav aria-label="Ranking view" className="flex">
      <Link
        href={homeHref({ show })}
        preserveScroll
        preserveState
        aria-current={overall ? undefined : 'page'}
        className={`${link} ${overall ? other : current}`}
      >
        By kind of work
      </Link>
      <Link
        href={homeHref({ show, overall: true })}
        preserveScroll
        preserveState
        aria-current={overall ? 'page' : undefined}
        className={`${link} ${overall ? current : other}`}
      >
        Overall top 10
      </Link>
    </nav>
  )
}
