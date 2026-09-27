## Context
Filtered home page: everything one teammate (Dan) picked, per kind of work. Casual, curious browsing by colleagues and subscribers ("what does Dan actually use?"). Low stakes, but it is a view of a person, so it must feel like a shelf, not a scoreboard.

## First Impressions
Clean and calm; the tool-square / model-circle language reads instantly and the 44px rank-1 tile against 30px rank 2-3 tiles gives each row a clear entry point. But the table is a narrow strip: all content sits in the left ~560px of a 1264px column, and each row carries an empty 210px right cell (5 empty `<td>`s). The result is a big dead right half under a 120px "DS" initials block that competes with the H1. The SHOW / PERSON menus contradict each other ("Every team" and "Dan" at once).

## Visual Design
**Sky blue misused** — "Dan" in the H1 is italic #9ce5f5. The brief reserves blue for the primary CTA, the active filter and the italic brand word. Here a name takes the brand accent, so it competes with "Loadout" in the header. Use #fdfaf7 italic (or plain) for the name.
**Text below the minimum** — "1st/2nd/3rd" (12px, lowercase mono, #8c8d91) and the "1M / high / medium" chips (12px mono, lowercase) break the "13px for anything but uppercase mono labels" rule. Count: 10 rank labels + 4 chips. Raise to 13px.
**Muted grey is at its floor** — legend text (13px #8c8d91) and rank labels are fine on contrast (~6:1 on #020202) but the legend is the only explanation of the tile shapes and sits far from the rows it explains.
**Empty right column and heavy avatar** — 120px "DS" tile (44px Newsreader) is the second-heaviest object on the page for zero information. 5 empty cells waste 210px each. Shrink the avatar to ~64px and delete the empty cell so the table breathes to full width or the rank column can widen.
**Weak distinction for rank 2-3 tools** — 14px/400 text plus 30px tiles is right hierarchy, spacing (4px row padding) is tight but OK.

## Interface Design
We're missing plain language on the chips: "high" and "1M" are unlabeled jargon. "high effort" / "1M context" (or a `title`) says what they are. Chips show only on Coding rows, so the pattern looks inconsistent rather than "optional".
Redundancy: identical Claude burst appears twice per row (square tool tile, round model tile) for Claude / Claude Fable 5.1; that is correct for the model, but Writing rank 1 and Classification rank 1 read as a stutter. Acceptable; do not add more.
Expectation setting: "Dan ranked 5 of 11 kinds of work" is good (counts, not points). "Last update Sep 17" needs "Last updated". Empty kinds are not explained; the sentence covers it.
Two dropdown pills link straight back to Home and do nothing here, and SHOW: "Every team" while filtered to one person is confusing.

## Consistency & Conventions
Product rules: no points, medals or people ranking; "1st/2nd/3rd" ranks are Dan's own picks, so this passes. Yellow is correctly absent. The "Back to everyone" link is a second way out beside the SHOW menu, so drop one. Table headers are serif 21px, consistent with home.

## User Context
Curious, browsing. The page respects that with only 5 rows, but the lopsided layout makes it feel unfinished. Uncommon care: make the filter state legible ("Showing: Dan") and give the chips words.

## Top Opportunities
1. Fix the filter controls so they describe the state.
2. Remove the blue on "Dan".
3. Lift 12px text to 13px and spell out chips.
4. Reclaim the empty column and shrink the avatar.
5. Drop the duplicate "Back to everyone" link.

## FIXES TO APPLY
1. SHOW menu: change the SHOW pill text from "Every team" to "One person" is wrong; instead set the SHOW pill to read `SHOW  Every team` only on Home. Here, replace the two pills with one: `PERSON  Dan ▾` (delete the SHOW `<a>`), because a person filter under a team filter contradicts itself.
2. H1: change the span color for "Dan" from #9ce5f5 to #fdfaf7 (keep italic). Blue is reserved for the brand word and active filter; the active PERSON pill may take a 1px #9ce5f5 inset border instead to mark it as the active filter.
3. Raise all 12px non-uppercase mono text to 13px: the ten "1st/2nd/3rd" labels (widen their box from 26px to 32px) and the "1M / high / medium" chips.
4. Chip copy: "1M" -> "1M context", "high" -> "high effort", "medium" -> "medium effort" (same chip styling), so no jargon is left unexplained.
5. Delete the five empty `<td style="...width:210px">` cells and shrink the "DS" avatar from 120px/44px to 72px/28px so the H1 stays the top of the hierarchy and the right side stops feeling abandoned.
6. Copy: "Last update Sep 17." -> "Last updated Sep 17." and remove the bottom "Back to everyone" paragraph (the PERSON menu already offers "Everyone"), which frees the space above the footer.
