import { Head, useForm, usePage } from '@inertiajs/react'
import { type FormEvent } from 'react'

interface SignInPageProps {
  flash: { alert?: string; notice?: string }
  [key: string]: unknown
}

export default function SignIn() {
  const { flash } = usePage<SignInPageProps>().props
  const form = useForm({ email_address: '', password: '' })

  function submit(event: FormEvent) {
    event.preventDefault()
    form.post('/session')
  }

  return (
    <>
      <Head title="Sign in" />
      <main className="mx-auto flex min-h-screen max-w-sm flex-col justify-center gap-6 px-6">
        <h1 className="text-2xl font-bold tracking-tight text-gray-900">Sign in</h1>

        {flash.alert && (
          <p role="alert" className="rounded bg-red-50 px-3 py-2 text-sm text-red-700">
            {flash.alert}
          </p>
        )}

        <form onSubmit={submit} className="flex flex-col gap-4">
          <label className="flex flex-col gap-1 text-sm">
            Email
            <input
              type="email"
              name="email_address"
              autoComplete="username"
              required
              value={form.data.email_address}
              onChange={(e) => form.setData('email_address', e.target.value)}
              className="rounded border border-gray-300 px-3 py-2"
            />
          </label>

          <label className="flex flex-col gap-1 text-sm">
            Password
            <input
              type="password"
              name="password"
              autoComplete="current-password"
              required
              value={form.data.password}
              onChange={(e) => form.setData('password', e.target.value)}
              className="rounded border border-gray-300 px-3 py-2"
            />
          </label>

          <button
            type="submit"
            disabled={form.processing}
            className="rounded bg-gray-900 px-3 py-2 text-white disabled:opacity-50"
          >
            Sign in
          </button>
        </form>
      </main>
    </>
  )
}
