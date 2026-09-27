import type { ReactNode } from 'react'

/** The small uppercase mono label above a value or a field; use for table headers and labels, too. */
export const sectionLabelClasses = 'font-mono text-xs font-normal uppercase tracking-[0.08em] text-fg-muted'

export default function SectionLabel({
  as: Tag = 'span',
  htmlFor,
  className = '',
  children,
}: {
  as?: 'span' | 'label' | 'p'
  htmlFor?: string
  className?: string
  children: ReactNode
}) {
  return (
    <Tag htmlFor={htmlFor} className={`${sectionLabelClasses} ${className}`}>
      {children}
    </Tag>
  )
}
