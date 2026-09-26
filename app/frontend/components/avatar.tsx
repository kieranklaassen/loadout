type Size = 'sm' | 'md' | 'lg' | 'xl'

const SIZES: Record<Size, string> = {
  sm: 'h-7 w-7 text-xs',
  md: 'h-10 w-10 text-sm',
  lg: 'h-16 w-16 text-xl',
  xl: 'h-28 w-28 text-4xl',
}

export function initials(name: string) {
  const parts = name.trim().split(/\s+/).filter(Boolean)
  const letters = parts.length > 1 ? parts[0][0] + parts[parts.length - 1][0] : (parts[0] ?? '?').slice(0, 2)
  return letters.toUpperCase()
}

export default function Avatar({
  name,
  src,
  size = 'md',
  className = '',
}: {
  name: string
  src: string | null
  size?: Size
  className?: string
}) {
  const classes = `inline-flex shrink-0 items-center justify-center overflow-hidden rounded-full bg-paper-deep font-serif text-ink ring-1 ring-rule ${SIZES[size]} ${className}`
  if (src) return <img src={src} alt="" className={`${classes} object-cover`} />
  return (
    <span aria-hidden="true" className={classes}>
      {initials(name)}
    </span>
  )
}
