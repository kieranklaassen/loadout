import everyLogo from '../assets/every-logo.svg'

/** The v1 Loadout glyph: three stacked slots. Still used by v1 pages until U13. */
export function LoadoutGlyph({ className = 'h-6 w-6' }: { className?: string }) {
  return (
    <svg viewBox="0 0 24 24" className={className} aria-hidden="true">
      <rect x="2" y="3" width="20" height="5" rx="2.5" fill="currentColor" />
      <rect x="2" y="9.5" width="14" height="5" rx="2.5" fill="#1652ea" />
      <rect x="2" y="16" width="8" height="5" rx="2.5" fill="currentColor" opacity="0.35" />
    </svg>
  )
}

/** The Every logo beside the italic sky "Loadout"; `sm` is the footer lockup. */
export default function Wordmark({ size = 'md', className = '' }: { size?: 'md' | 'sm'; className?: string }) {
  const small = size === 'sm'

  return (
    <span className={`inline-flex items-center gap-2 ${className}`}>
      <img src={everyLogo} alt="Every" className={`w-auto opacity-95 invert ${small ? 'h-[18px]' : 'h-[22px]'}`} />
      {!small && <span aria-hidden="true" className="mx-2 h-[22px] w-px bg-line-strong" />}
      <span className={`font-serif italic leading-none text-sky ${small ? 'text-lg' : 'text-[28px]'}`}>Loadout</span>
    </span>
  )
}
