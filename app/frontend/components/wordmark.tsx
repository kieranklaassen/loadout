import everyLogo from '../assets/every-logo.svg'

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
