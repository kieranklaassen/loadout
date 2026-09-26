import type { CatalogItem } from '../types'

type Size = 'xs' | 'sm' | 'md' | 'lg' | 'xl'

const SIZES: Record<Size, string> = {
  xs: 'h-5 w-5 rounded-md text-[0.55rem]',
  sm: 'h-7 w-7 rounded-lg text-[0.65rem]',
  md: 'h-10 w-10 rounded-xl text-sm',
  lg: 'h-14 w-14 rounded-2xl text-lg',
  xl: 'h-20 w-20 rounded-3xl text-2xl',
}

/** Brand hue to a tile colour pair. Marks are typographic: no third-party logos. */
export function markColors(hue: number) {
  return {
    background: `hsl(${hue} 70% 92%)`,
    color: `hsl(${hue} 65% 24%)`,
    borderColor: `hsl(${hue} 45% 80%)`,
  }
}

export default function ToolMark({
  item,
  size = 'md',
  className = '',
}: {
  item: Pick<CatalogItem, 'hue' | 'monogram' | 'name'>
  size?: Size
  className?: string
}) {
  return (
    <span
      aria-hidden="true"
      title={item.name}
      style={markColors(item.hue)}
      className={`inline-flex shrink-0 select-none items-center justify-center border font-mono font-medium tracking-tight ${SIZES[size]} ${className}`}
    >
      {item.monogram}
    </span>
  )
}
