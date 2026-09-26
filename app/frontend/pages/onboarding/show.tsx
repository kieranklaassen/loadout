import { Head } from '@inertiajs/react'
import AppShell from '../../components/app_shell'

export default function OnboardingShow({ suggested_handle }: { suggested_handle: string }) {
  return (
    <AppShell>
      <Head title="Welcome" />
      <h1 className="display text-5xl">Claim loadout.every.to/{suggested_handle}</h1>
    </AppShell>
  )
}
