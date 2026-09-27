# EveryHome review

## Context
Public landing page for Every Loadout: what the team uses, latest model launches, then a Join Every pitch. Audience: curious Every readers, often signed out, browsing casually.

## First Impressions
Clear and calm. The title, one sentence and the marble illustration give a strong entry point, and the tool-vs-model split (square vs round tile, two labelled columns) works. It then turns into a dense table: 11 rows, each with a lead item plus 0-2 runners-up per column, about 45 tiles and 90 small text lines. The signed-out visitor sees the answer to "what should I use?" only after scanning all of it.

## Visual Design
**Text below the minimum** — NEWEST badge is 11px (rule: 12px for mono caps). All runner-up counts ("2", "1") and the line "Most run it at 1M context, high effort" are 12px non-uppercase (rule: 13px). About 25 instances. Small, faint, and against the brief.

**Coral used for non-danger** — Coral #ff7765 appears 5 times (Research, Classification, Animation, Text to speech, Music). Two of them, "1 pick not confirmed yet", are not stale or danger; that is a normal state. Five red lines make half the table look broken on a public page. Keep coral for "Not updated in N weeks" only; drop the unconfirmed line here (it is a private, per-person concept).

**Active filter is off-palette** — "By kind of work" is filled cream #fdfaf7. Brief: active filter is sky blue #9ce5f5. The top row of the page then has two blue and one cream control competing.

**Muted grey carries too much** — #8c8d91 on #020202 is about 6.1:1 (passes), on #111 about 5.6:1, but it is used for the legend, every subtitle, every count and every date. Result: the page's second-level info all reads at the same dim weight. Counts ("5 of 6 use it") are the product's core fact and should be #d0d0d0.

**Repeated art** — The same marble/yellow collage appears in hero and Join block, cropped differently. Reads as reuse; the yellow block also spends the yellow accent that is meant for NEWEST/rank-1.

## Interface Design
**Two filters that do nothing visible** — "SHOW Every team ▾" and "PERSON All of us ▾" say nearly the same thing (both scope the data) and neither shows a selected state. We are missing a chance to cut one control and make the remaining one obvious.

**Runner-ups double the table's weight** — Each cell repeats the leader's structure with a smaller row of tiles. The row's job is "what's the top pick", and "See how our #1 picks changed" plus the kind pages already cover depth. Show leader only, with count; keep at most one runner-up.

**Legend duplicates the headers** — "Tool: the app you use / Model: the AI behind it" sits above columns already titled MOST USED TOOL / MOST USED MODEL. Put the explanation into the header cells (small square/round tile + "the app" / "the AI behind it") and remove the separate row.

**Launch rows** — "2 of 6 are trying it" vs "4 of 6 use it, mostly in Claude Code" wraps to two lines and uses different verbs. Every link repeats "Vibe Check:" (3 times) plus the arrow; the section already links "All Vibe Checks".

## Consistency & Conventions
Tool and model tiles are correctly square vs round everywhere. "Sign in / Rank your tools" in the header: a signed-out visitor cannot rank without joining, so the primary button over-promises and there are then two sky CTAs (header, Join Every). Table row titles are links with no affordance beyond colour-identical text.

## User Context
Feeling: informed but slightly overloaded by the table. Uncommon care: let the newest launch and the coding row (most-asked) breathe; keep everything else quiet.

## Top Opportunities
1. Enforce min text sizes (11px badge, 12px counts).
2. Remove coral from non-stale lines.
3. Trim runner-ups so each cell is one pick.
4. Sky-blue active tab; drop redundant filter/legend.

---
## FIXES TO APPLY
1. Text sizes: change NEWEST badge font-size 11px -> 12px; change every runner-up count span `font-size:12px` -> 13px; delete the "Most run it at 1M context, high effort" div (Coding row). Why: brief minimums, and it is the only row with such a line.
2. Coral: delete both "1 pick not confirmed yet" spans (Research, Animation). Keep the three "Not updated in..." lines in coral. Why: coral is stale/danger only; unconfirmed picks are a private-by-default concept.
3. Active tab: on "By kind of work" set background #9ce5f5 (keep color #121212). Why: sky blue is the active-filter colour.
4. Trim runner-ups: in each table cell keep only the first runner-up (remove the second `inline-flex` chip in Coding, Research, Video cells). Why: fewer tiles, leader stays the answer, cleaner scan.
5. Merge the two filter pills: remove the "PERSON All of us" pill (keep "SHOW Every team"). Remove the tool/model legend row; instead in the two `th` headers change copy to "MOST USED TOOL (THE APP)" and "MOST USED MODEL (THE AI BEHIND IT)" at 12px. Why: one control, no duplicated explanation.
6. Copy: launch link text drop the "Vibe Check: " prefix (keep title and ↗); change "2 of 6 are trying it" to "2 of 6 use it"; change header CTA "Rank your tools" to "Join Every". Make lead counts ("5 of 6 use it") colour #d0d0d0. Why: consistent verbs, shorter rows, honest CTA, core fact more legible.
