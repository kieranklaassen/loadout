import { fireEvent, render, screen } from '@testing-library/react'
import type { ReactNode } from 'react'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import SignIn from './sign_in'

const post = vi.fn()
let flash: { alert?: string } = {}
vi.mock('@inertiajs/react', () => ({
  Head: () => null,
  Link: ({ children, href, ...rest }: { children: ReactNode; href: string }) => (
    <a href={href} {...rest}>
      {children}
    </a>
  ),
  usePage: () => ({ props: { flash } }),
  router: { post: (...args: unknown[]) => post(...args) },
}))

describe('SignIn page', () => {
  beforeEach(() => {
    post.mockReset()
    flash = {}
  })

  it('offers only Sign in with Every, as a full navigation to /auth/every', () => {
    render(<SignIn />)

    const link = screen.getByRole('link', { name: /sign in with every/i })
    expect(link).toHaveAttribute('href', '/auth/every')
    expect(screen.queryByLabelText(/password/i)).not.toBeInTheDocument()
    expect(screen.queryByRole('heading', { name: /dev login/i })).not.toBeInTheDocument()
  })

  it('surfaces a sign-in failure from flash', () => {
    flash = { alert: 'Sign in with Every did not complete. Try again.' }
    render(<SignIn />)

    expect(screen.getByRole('alert')).toHaveTextContent('did not complete')
  })

  it('lists dev login people and posts the chosen email to /dev/login', () => {
    render(<SignIn dev_login_people={[{ email: 'dev@every.to', name: 'Dev Person' }]} />)

    fireEvent.click(screen.getByRole('button', { name: /continue as dev person/i }))

    expect(post).toHaveBeenCalledWith('/dev/login', { email_address: 'dev@every.to' })
  })

  it('tells the developer to seed when the dev login has nobody to offer', () => {
    render(<SignIn dev_login_people={[]} />)

    expect(screen.getByText(/db:seed/)).toBeInTheDocument()
  })
})
