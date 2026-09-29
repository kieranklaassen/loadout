import { VISIBILITY_CONSEQUENCE, VISIBILITY_HELP, VISIBILITY_LABEL, VISIBILITY_LEVELS } from '../lib/visibility_copy'
import type { Visibility } from '../types'

/**
 * "Who can see it": Only me, Every team, Anyone with the link, as radio cards. The
 * selected card is followed by what that choice means (the same lines on Claim your
 * link and Settings). `labelledBy` is the id of the heading that names the group.
 */
export default function VisibilityChoice({
  value,
  onChange,
  labelledBy,
  error,
}: {
  value: Visibility
  onChange: (level: Visibility) => void
  labelledBy: string
  error?: string
}) {
  return (
    <div role="radiogroup" aria-labelledby={labelledBy} className="flex flex-col gap-2.5">
      {VISIBILITY_LEVELS.map((level) => {
        const selected = value === level
        return (
          <div key={level}>
            <label className="radio-card">
              <input
                type="radio"
                name="visibility"
                value={level}
                checked={selected}
                onChange={() => onChange(level)}
                aria-describedby={selected ? 'visibility-consequence' : undefined}
              />
              <span className="radio-dot" />
              <span>
                <span className="block text-base font-semibold text-fg">{VISIBILITY_LABEL[level]}</span>
                <span className="mt-[3px] block text-sm leading-[1.45] text-fg-muted">{VISIBILITY_HELP[level]}</span>
              </span>
            </label>
            {selected && (
              <p id="visibility-consequence" className="mt-2 text-sm leading-[1.45] text-fg-soft">
                {VISIBILITY_CONSEQUENCE[level]}
              </p>
            )}
          </div>
        )
      })}
      {error && (
        <p role="alert" className="text-sm text-coral">
          {error}
        </p>
      )}
    </div>
  )
}
