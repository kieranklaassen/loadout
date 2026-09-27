import { Link } from '@inertiajs/react'
import type { ComponentProps, ReactNode } from 'react'

type Variant = 'primary' | 'secondary' | 'ghost' | 'blue'

const VARIANTS: Record<Variant, string> = {
  primary: 'bg-ink text-paper hover:bg-ink-soft shadow-[0_10px_24px_-14px_rgb(18_18_18/0.8)]',
  secondary: 'bg-white text-ink ring-1 ring-rule hover:ring-ink/30',
  ghost: 'text-ink hover:bg-ink/5',
  blue: 'bg-every-blue text-white hover:bg-every-blue/90 shadow-[0_10px_24px_-14px_rgb(22_82_234/0.9)]',
}

export function buttonClasses(variant: Variant = 'primary', size: 'md' | 'lg' = 'md') {
  const sizing = size === 'lg' ? 'px-6 py-3.5 text-base' : 'px-4 py-2.5 text-sm'
  return `inline-flex items-center justify-center gap-2 rounded-full font-medium transition active:scale-[0.98] disabled:pointer-events-none disabled:opacity-50 ${sizing} ${VARIANTS[variant]}`
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
