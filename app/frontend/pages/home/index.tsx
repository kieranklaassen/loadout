import { Head } from '@inertiajs/react'

interface HomeProps {
  name: string
}

export default function Home({ name }: HomeProps) {
  return (
    <>
      <Head title="Home" />
      <main className="mx-auto flex min-h-screen max-w-2xl flex-col justify-center gap-6 px-6">
        <h1 className="text-4xl font-bold tracking-tight text-gray-900">
          Hello, {name}
        </h1>
        <p className="text-lg text-gray-600">
          This is the canonical Rails + Inertia + React template. Rails owns
          routes and props; this page reads them directly — there is no parallel
          JSON API to keep in sync.
        </p>
      </main>
    </>
  )
}
