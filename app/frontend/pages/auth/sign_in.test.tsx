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
  usePage: () => ({ props: { flash, public_host: 'loadout.example.test', current_user: null }, url: '/session/new' }),
  router: { post: (...args: unknown[]) => post(...args) },
}))

const JOIN = 'https://join.example.test'

describe('SignIn page', () => {
  beforeEach(() => {
    post.mockReset()
    flash = {}
  })

  it('offers only Sign in with Every, as a full navigation to /auth/every', () => {
    render(<SignIn join_every_url={JOIN} />)

    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('Sign in with Every')
    const link = screen.getByRole('link', { name: /sign in with every/i })
    expect(link).toHaveAttribute('href', '/auth/every')
    expect(screen.queryByLabelText(/password/i)).not.toBeInTheDocument()
    expect(screen.queryByRole('heading', { name: /dev login/i })).not.toBeInTheDocument()
  })

  it('says who can sign in and that everyone else can still read the page', () => {
    render(<SignIn join_every_url={JOIN} />)

    expect(screen.getByText(/members of the every team and every subscribers can sign in/i)).toBeInTheDocument()
    expect(screen.getByText(/everyone else can still read the team’s public page/i)).toBeInTheDocument()
  })

  it('states that name, photo and email are read', () => {
    render(<SignIn join_every_url={JOIN} />)

    expect(screen.getByText(/we read your name, photo and email from your every account/i)).toBeInTheDocument()
    expect(screen.queryByText(/only read your name and photo/i)).not.toBeInTheDocument()
  })

  it('links Join Every to the address the server sends and the team page to Home', () => {
    render(<SignIn join_every_url={JOIN} />)

    expect(screen.getByRole('link', { name: 'Join Every' })).toHaveAttribute('href', JOIN)
    expect(screen.getByRole('link', { name: /read the team’s page/i })).toHaveAttribute('href', '/')
  })

  it('surfaces a sign-in failure from flash', () => {
    flash = { alert: 'Sign in with Every did not complete. Try again.' }
    render(<SignIn join_every_url={JOIN} />)

    expect(screen.getByRole('alert')).toHaveTextContent('did not complete')
  })

  it('lists dev login people and posts the chosen email to /dev/login', () => {
    render(<SignIn join_every_url={JOIN} dev_login_people={[{ email: 'dev@every.to', name: 'Dev Person' }]} />)

    expect(screen.getByRole('heading', { name: /dev login/i })).toBeInTheDocument()
    fireEvent.click(screen.getByRole('button', { name: /continue as dev person/i }))

    expect(post).toHaveBeenCalledWith('/dev/login', { email_address: 'dev@every.to' })
  })

  it('tells the developer to seed when the dev login has nobody to offer', () => {
    render(<SignIn join_every_url={JOIN} dev_login_people={[]} />)

    expect(screen.getByText(/db:seed/)).toBeInTheDocument()
  })
})
