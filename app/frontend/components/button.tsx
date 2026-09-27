import { Link } from '@inertiajs/react'
import type { ComponentProps, ReactNode } from 'react'

type Variant = 'primary' | 'secondary' | 'ghost' | 'danger'

const VARIANTS: Record<Variant, string> = {
  primary: 'bg-sky text-on-light hover:bg-sky/85',
  secondary: 'border border-line bg-panel text-fg hover:border-line-strong',
  ghost: 'text-fg hover:bg-fg/5',
  danger: 'bg-coral text-on-light hover:bg-coral/85',
}

export function buttonClasses(variant: Variant = 'primary', size: 'md' | 'lg' = 'md') {
  const sizing = size === 'lg' ? 'px-6 py-3.5 text-base' : 'px-4 py-2.5 text-sm'
  return `inline-flex min-h-11 items-center justify-center gap-2 rounded-sharp font-semibold transition-colors md:min-h-0 disabled:pointer-events-none disabled:opacity-50 aria-disabled:cursor-not-allowed aria-disabled:opacity-50 ${sizing} ${VARIANTS[variant]}`
}

type ButtonProps = ComponentProps<'button'> & { variant?: Variant; size?: 'md' | 'lg'; children: ReactNode }

export default function Button({ variant = 'primary', size = 'md', className = '', type = 'button', ...rest }: ButtonProps) {
  return <button type={type} className={`${buttonClasses(variant, size)} ${className}`} {...rest} />
}

export function ButtonLink({
  variant = 'primary',
  size = 'md',
  className = '',
  ...rest
}: Omit<ComponentProps<typeof Link>, 'size'> & { variant?: Variant; size?: 'md' | 'lg' }) {
  return <Link className={`${buttonClasses(variant, size)} ${className}`} {...rest} />
}
