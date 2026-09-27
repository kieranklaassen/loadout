import type { ProfileProps } from '../pages/profiles/show'
import { codingKind, musicKind, writingKind } from './home_fixtures'
import { claudeCodeMark, cursorMark, markItem, opusMark, rankedPick } from './picker_fixtures'

export const claude = markItem('claude', 'Claude', 'tool', 'claude')
export const gpt = markItem('gpt-6-astra', 'GPT-6 Astra', 'model', 'openai')

/** Dan ranks Coding (Claude Code with Opus 5.5 at 1M and high, then Cursor) and Writing (Claude, no model); Music is unranked. */
export const profileProps = (overrides: Partial<ProfileProps> = {}): ProfileProps => ({
  person: { handle: 'dan', name: 'Dan Every', avatar_url: null },
  ranked_count: 2,
  kinds: [
    {
      category: codingKind,
      picks: [
        rankedPick({ rank: 1, tool: claudeCodeMark, model: opusMark, context: '1m', effort: 'high' }),
        rankedPick({ rank: 2, tool: cursorMark, model: null }),
      ],
      team_uses: null,
    },
    { category: writingKind, picks: [rankedPick({ rank: 1, tool: claude, model: null })], team_uses: null },
    { category: musicKind, picks: [], team_uses: null },
  ],
  new_in_loadout: [],
  bio: 'Claude Code for everything that ships.',
  viewer_can_compare: false,
  you: {},
  copy_url: 'https://loadout.every.to/dan',
  ...overrides,
})

/** What a signed-in viewer ranks: Coding (Cursor with GPT-6) and Video, but not Writing. */
export const yourPicks: ProfileProps['you'] = {
  coding: [rankedPick({ rank: 1, tool: cursorMark, model: gpt }), rankedPick({ rank: 2, tool: claudeCodeMark, model: null })],
  video: [rankedPick({ rank: 1, tool: markItem('runway', 'Runway'), model: null })],
}
