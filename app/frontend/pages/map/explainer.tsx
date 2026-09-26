import { Head } from '@inertiajs/react'
import AppShell from '../../components/app_shell'
import { buttonClasses, ButtonLink } from '../../components/button'

const SKETCH = [
  { label: 'Coding', bars: [0.92, 0.64, 0.38, 0.2] },
  { label: 'Knowledge work', bars: [0.81, 0.47, 0.29] },
  { label: 'Video', bars: [0.58, 0.33] },
]

const POINTS = [
  {
    title: 'Counted, not named',
    body: 'Every loadout at Every adds to the totals. Only people who made their profile public are shown by name; everyone else is "and 3 others".',
  },
  {
    title: 'Built for discovery',
    body: "It shows members the kinds of work they haven't set up yet, what colleagues use there, and when the team has moved to a newer model.",
  },
  {
    title: 'Every only, for now',
    body: 'The map is for people with an @every.to address. A public version may open later.',
  },
]

/** A wordless sketch of the map: bars without names or numbers, so nothing leaks. */
function Sketch() {
  return (
    <figure aria-hidden="true" className="card relative overflow-hidden p-6 sm:p-8">
      <div className="flex flex-col gap-7">
        {SKETCH.map((row, rowIndex) => (
          <div key={row.label}>
            <p className="eyebrow">
              {String(rowIndex + 1).padStart(2, '0')} · {row.label}
            </p>
            <div className="mt-3 flex flex-col gap-3">
              {row.bars.map((share, index) => (
                <div key={index} className="flex items-center gap-3">
                  <span className="h-6 w-6 shrink-0 rounded-lg border border-rule bg-paper-deep" />
                  <div className="flex-1">
                    <span className="block h-2 w-24 rounded-full bg-paper-deep" />
                    <div className="mt-1.5 h-1.5 overflow-hidden rounded-full bg-paper-deep">
                      <div
                        className={`animate-rise h-full rounded-full ${index === 0 ? 'bg-every-blue/80' : 'bg-ink/25'}`}
                        style={{ width: `${share * 100}%`, animationDelay: `${(rowIndex * 3 + index) * 70}ms` }}
                      />
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        ))}
      </div>
      <div className="pointer-events-none absolute inset-x-0 bottom-0 h-24 bg-gradient-to-t from-white to-transparent" />
    </figure>
  )
}

export default function MapExplainer({ signed_in }: { signed_in: boolean }) {
  return (
    <AppShell wide>
      <Head title="The Every map" />

      <div className="grid gap-12 lg:grid-cols-[1.1fr_1fr] lg:items-center lg:gap-16">
        <div className="animate-rise">
          <p className="eyebrow">The Every map</p>
          <h1 className="display mt-4 text-5xl sm:text-7xl">
            What a whole company <em className="text-every-blue">runs on.</em>
          </h1>
          <p className="mt-6 max-w-xl text-lg leading-relaxed text-ink-soft">
            People at Every keep a Loadout: the AI tools and models they use for each kind of work. The map adds them up, so
            anyone on the team can see what colleagues reach for and find something worth trying.
          </p>
          <div className="mt-8 flex flex-wrap items-center gap-3">
            {signed_in ? (
              <>
                <ButtonLink href="/" size="lg">
                  Keep your own loadout
                </ButtonLink>
                <p className="text-sm text-ink-muted">The map is only open to people at Every.</p>
              </>
            ) : (
              <>
                <a href="/auth/every" className={buttonClasses('primary', 'lg')}>
                  Sign in with Every
                </a>
                <p className="text-sm text-ink-muted">Work at Every? Sign in to see the map.</p>
              </>
            )}
          </div>
        </div>

        <div className="animate-rise [animation-delay:120ms]">
          <Sketch />
        </div>
      </div>

      <ol className="mt-20 grid gap-8 border-t border-rule pt-10 md:grid-cols-3">
        {POINTS.map((point, index) => (
          <li key={point.title}>
            <p className="font-mono text-xs text-every-blue">{String(index + 1).padStart(2, '0')}</p>
            <h2 className="display mt-2 text-2xl">{point.title}</h2>
            <p className="mt-2 leading-relaxed text-ink-soft">{point.body}</p>
          </li>
        ))}
      </ol>
    </AppShell>
  )
}
