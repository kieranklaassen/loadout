/** The Loadout wordmark: three stacked slots (a loadout) beside a serif name. */
export function LoadoutGlyph({ className = 'h-6 w-6' }: { className?: string }) {
  return (
    <svg viewBox="0 0 24 24" className={className} aria-hidden="true">
      <rect x="2" y="3" width="20" height="5" rx="2.5" fill="currentColor" />
      <rect x="2" y="9.5" width="14" height="5" rx="2.5" fill="#1652ea" />
      <rect x="2" y="16" width="8" height="5" rx="2.5" fill="currentColor" opacity="0.35" />
    </svg>
  )
}

export default function Wordmark({ className = '' }: { className?: string }) {
  return (
    <span className={`inline-flex items-center gap-2 ${className}`}>
      <LoadoutGlyph />
      <span className="font-serif text-[1.45rem] font-medium leading-none tracking-tight">Loadout</span>
    </span>
  )
}
