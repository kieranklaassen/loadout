# EveryProfile2 review

## Context
A member's public-facing profile (Lucas Crespo). Visitors arrive from a shared link or from the team page, casually curious: "what does he use, and how does it differ from me?" Low stakes, browsing mood.

## First Impressions
The identity column is strong: a 56px serif name, one warm sentence of bio, and a single sky-blue "Copy link". The right side is the problem. Of 11 rows, 5 say "Not ranked yet" (Research, Classification, Animation, Text to speech, Music), so 45% of the list is grey filler. The 210px right-hand column in every row is empty: the brief's "team's most used tool where it differs" is missing entirely, leaving a dead strip on the right. The page reads as a half-filled form, not a profile worth sharing.

## Visual Design
**Empty team column** — every `<td>` at width:210px is blank in all 11 rows. The tools/models legend promises a comparison that never appears; the row content hugs the left and the right third is void.
**Wrong count** — "7 of 11 kinds of work" but only 6 rows have picks (Coding, Knowledge work, Writing, Image, Video, Speech to text). A public number that is visibly wrong.
**Filler rows** — 5 "Not ranked yet" rows at 14px #8c8d91 take ~150px and pull the eye as much as the real picks.
**Redundant heading** — h1 "Lucas Crespo" (56px) then h2 "Lucas's loadout" (40px), two serif headlines about the same person, 3 serif sizes in view.
**Rank sizing works, model text is small** — 1st = 44px tile + 16px/600 name; 2nd/3rd = 30px tile + 14px/400. Good hierarchy. But model names are 13px #d0d0d0 next to 20px round tiles; they are the least legible element, while the tool-vs-model shape rule (square vs round) is clear. Contrast is fine (#8c8d91 on #020202 is about 6:1; #d0d0d0 is about 13:1).
**Chips** — "1M" and "high" appear only on Coding (4 chips out of 13 picks). Unlabelled, they read as jargon, and they make the two Coding rows look different from all others.
**Label alignment** — row label (21px serif) is top-aligned while the 44px tile is centred at 22px down, so label baseline and tool name do not line up.

## Interface Design
We're missing an opportunity to lead with the answer: the team comparison is the reason to click "Compare with mine", and it's absent. Progressive disclosure is inverted: empty categories get full rows while real picks are dense. Monologue (Speech to text) has a tool but no model, unlike every other pick; unexplained.

## Consistency & Conventions
Tool/model tile shapes match the brief. The Claude sunburst is used for both the tool "Claude" and the model "Claude Fable 5.1" in the same row; shape is the only cue. Header nav "Your profile" (KK) links to Lucas's page, and "Copy link" points to itself. Footer "Private by default. Public when you want." speaks to the owner, not to the visitor reading a shared profile.

## User Context
A visitor feels: nice person, thin page. Five empty rows read as "he didn't finish", which is the opposite of the confidence a shared profile should give. Uncommon care: show only what he chose, and make the one comparison ("the team uses X") effortless.

## Top Opportunities
1. Collapse empty kinds into one line.
2. Fill the right column with the team's top tool only where it differs, or drop the column.
3. Fix "7 of 11" to 6.
4. Remove the duplicate h2.
5. Make model text and chips more readable.

## FIXES TO APPLY
1. **Collapse the 5 "Not ranked yet" rows into one row.** Delete those 5 `<tr>`s. After the Speech to text row add a single last `<tr>` with th "Not ranked yet" (21px serif st, muted #8c8d91) and a td with plain text 14px #8c8d91: "Research, Classification, Animation, Text to speech, Music". Saves ~120px, removes filler, and reads as honest rather than unfinished. (Keep the order of ranked kinds unchanged.)
2. **Populate the right column, only where the team's top tool differs.** Right-align in the existing 210px td, 13px #d0d0d0, with a 12px mono uppercase muted label "TEAM USES" above it, then a 20px square tile + tool name + "4 of 6" in muted. Suggested: Image (Gemini, 4 of 6), Video (Veo, 3 of 5), Speech to text (Whisper, 4 of 5). Leave every other td empty. Why: this is the brief's comparison, and it makes "Compare with mine" meaningful. Counts, not points.
3. **Fix the count**: change "7 of 11 kinds of work" to "6 of 11 kinds of work" (six rows have picks).
4. **Remove the duplicate h2.** Replace "Lucas's loadout" (40px) with a 22px `st` "Top picks by kind of work" or drop it and let the legend sit on the border line alone. Keeps one dominant headline (the name).
5. **Raise model and chip legibility.** Model name 13px to 14px #fdfaf7 secondary; tool sub-rows (2nd/3rd) can stay 14px. Render chips as words: "1M context" and "High effort" (12px mono, same chip style), and apply consistently wherever a pick has them. Vertically align row label with the first tool line (`th` padding-top 24px or vertical-align: middle on 1st row).
6. **Make the footer and links right for a visitor.** Footer right text: "Updated Sep 19. Only Lucas edits this page." (drop "Private by default..." from a shared profile). Point the header avatar "KK" link to EveryEdit.dc.html, not to this page, and point "Copy link" at a real `#` copy target rather than itself.
