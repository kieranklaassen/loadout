import type { Visibility } from '../types'

// One set of words for the three visibility levels, shared by Claim your link,
// Settings and the Rank editor so the consequence is always stated the same way.

export const VISIBILITY_LEVELS: Visibility[] = ['only_me', 'team', 'link']

export const VISIBILITY_LABEL: Record<Visibility, string> = {
  only_me: 'Only me',
  team: 'Every team',
  link: 'Anyone with the link',
}

export const VISIBILITY_HELP: Record<Visibility, string> = {
  only_me: 'Nobody else sees your picks.',
  team: 'People on the Every team.',
  link: 'Anyone with your link, and anyone browsing the Every page.',
}

export const VISIBILITY_CONSEQUENCE: Record<Visibility, string> = {
  only_me: 'Nobody else sees your picks. Cards already shared cannot be recalled.',
  team: 'People on the Every team can read your picks, and so can their connected agents.',
  link: 'Listed on the Every page and searchable by anyone. Cards already shared cannot be recalled.',
}

// The short line the Rank editor shows above the slots.
export const VISIBILITY_STATUS: Record<Visibility, string> = {
  only_me: 'Only you can see this.',
  team: 'People on the Every team can see this.',
  link: 'Anyone with the link can see this and find you in search.',
}
