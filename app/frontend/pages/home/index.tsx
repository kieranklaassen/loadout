import { Head } from '@inertiajs/react'
import { buttonClasses } from '../../components/button'
import Wordmark from '../../components/wordmark'

export default function Home() {
  return (
    <>
      <Head title="What's in your AI loadout?" />
      <main className="mx-auto flex min-h-screen max-w-3xl flex-col justify-center gap-8 px-6">
        <Wordmark />
        <h1 className="display text-6xl">What's in your AI loadout?</h1>
        <a href="/auth/every" className={`${buttonClasses('primary', 'lg')} self-start`}>
          Sign in with Every
        </a>
      </main>
    </>
  )
}
