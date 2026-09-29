import { markSvg } from '../lib/marks'
import type { MarkItem } from '../types'

type Size = 'xs' | 'sm' | 'md' | 'lg' | 'xl'

const SIZES: Record<Size, string> = {
  xs: 'size-[22px] text-[13px]',
  sm: 'size-7 text-[15px]',
  md: 'size-9 text-base',
  lg: 'size-11 text-lg',
  xl: 'size-[52px] text-[22px]',
}

/** A light tile for a tool (square) or a model (round): its real mark when the catalog has one, else the name's first letter in the serif face. */
export default function Mark({
  item,
  size = 'md',
  className = '',
}: {
  item: Pick<MarkItem, 'name' | 'kind' | 'mark'>
  size?: Size
  className?: string
}) {
  const svg = markSvg(item.mark)
  const shape = item.kind === 'model' ? 'rounded-full' : 'rounded-soft'

  return (
    <span
      aria-hidden="true"
      title={item.name}
      data-kind={item.kind}
      className={`inline-flex shrink-0 select-none items-center justify-center bg-fg text-on-light ${shape} ${SIZES[size]} ${className}`}
    >
      {svg ? (
        <span className="block h-[54%] w-[54%] [&>svg]:h-full [&>svg]:w-full" dangerouslySetInnerHTML={{ __html: svg }} />
      ) : (
        <span className="font-serif font-medium leading-none">{firstLetter(item.name)}</span>
      )}
    </span>
  )
}

function firstLetter(name: string) {
  return (Array.from(name.trim())[0] ?? '?').toUpperCase()
}
