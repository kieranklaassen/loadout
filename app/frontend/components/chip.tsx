import type { ReactNode } from 'react'
import type { PickContext, PickEffort } from '../types'

type Tone = 'neutral' | 'newest'

const TONES: Record<Tone, string> = {
  neutral: 'bg-raised text-fg ring-1 ring-line-strong font-mono text-caption',
  newest: 'bg-yellow text-on-light font-mono text-xs font-medium uppercase tracking-[0.08em]',
}

/** A small mono tag: a pick's context or effort, "Pending review", or (yellow) NEWEST. */
export default function Chip({ tone = 'neutral', className = '', children }: { tone?: Tone; className?: string; children: ReactNode }) {
  return <span className={`inline-flex items-center rounded-sharp px-[7px] py-0.5 ${TONES[tone]} ${className}`}>{children}</span>
}

export const contextLabel = (context: PickContext) => `${context.toUpperCase()} context`

export const effortLabel = (effort: PickEffort) => `${effort} effort`
