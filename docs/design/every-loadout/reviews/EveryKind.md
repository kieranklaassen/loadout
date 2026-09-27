## Context
The "Coding" kind-of-work page on Every Loadout. A staff member or subscriber arrives from Home, casually curious ("what does Every actually use to code?"), possibly deciding what to try. Low stakes, browsing.

## First Impressions
Clean and calm. The 72px serif "Coding" and the two-column Tools / Models split give an immediate answer, and the square-vs-round tile language works. But the page then piles three more blocks onto the top section: a "how we run them" table, a large expanded card for one tool, and three one-line summaries. The lower half reads like a different, denser page. The numbers also don't add up, which undermines the "5 of 6" honesty the product depends on.

## Visual Design
**Off-palette color** — The Sep 2026 history card uses a 2px sky-blue (#9ce5f5) ring, and the love dot is a new green (#6ee7a0). Sky blue is reserved for the CTA, active filter and brand word, and green is not in the language at all. The newest step should use yellow #f6b90f. Coral for "don't love" is also stretching "stale/danger only". Use a neutral dot or none, since the two column headings already say love / don't love.
**Contrast failures** — "with" between tool and model and the history arrows are #5a5a5a on #020202, about 2.7:1. The history model circles are flat #5a5a5a blanks, so they look like missing images and break the light round tile rule.
**Undersized text** — Take initials are 11px mono (KK, DS, KP, LC), below the 13px floor for non-uppercase text. Sub-lines and counts sit at 14px in #8c8d91 (about 6:1, passes, but a weak second tier). The 13px sample-copy footnote is a design annotation and should not ship in the layout.
**Type scale** — Nine sizes are in play (72, 36, 32, 20, 17, 16, 15, 14, 13). Rows use 15, 16 and 17px for the same role (item name). Pick one.

## Interface Design
**The numbers contradict each other** — Claude Code says "5 of 6" but the line under it names only 4 people as 1st, and Cursor and Codex account for 3 more. How-we-run rows for Opus total 3+1+1 = 5, yet Opus says "4 of 6". Codex is "1st for Rob" with GPT-6 Sol, while Sonnet 4.5 is "Used by Rob". Counts are the product's only proof, so they must reconcile.
**Redundancy** — "How we run them" repeats every tool and model already listed above it, with a third set of tiles. Its heading is jargon in mono caps ("TOOL, MODEL, CONTEXT, EFFORT"), and "1M / high" chips have no labels. Below that, the Takes section repeats them again, once as a card and once as rows.
**Tools vs models blurred in Takes** — Claude Code gets a full 300px card while the other three get rows that start with "Model." or "Tool." as a sentence prefix. The tile shape already says which is which, and the text shouldn't have to. The card also carries a "TOOL" tag.
**Focus** — The CTA is clear. Below the first fold, four different containers (list rows, chip table, big card, mini rows) compete equally.

## Consistency & Conventions
The takes card uses a box-shadow ring while `.card` uses a border. "Trying: Dan (2nd), Katie (3rd)" breaks the "Nth for" / "Used by" sub-line pattern. History is the only place with a right-pointing arrow row and a highlight color.

## User Context
Casual browsing wants one confident answer per column. Right now the reader must reconcile four sets of counts. Uncommon care would be one truthful number per item and takes reached in one place.

## Top Opportunities
1. Reconcile counts across Tools, Models and How we run them.
2. Cut the duplication in "How we run them" and Takes.
3. Bring color back to the palette (yellow newest, no green).
4. Fix contrast and the 11px initials.

---

## FIXES TO APPLY

1. **Make the numbers consistent.** Pick one dataset for 6 people. Suggested: Claude Code 4 of 6 (Kieran, Dan, Katie, Lucas at 1st; add "3rd for X" only if it fits), Cursor 2 of 6, Codex 1 of 6 (Rob); Opus 5.5 = 3+1+1 = 5 of 6, Sonnet 4.5 becomes "Used by Rob" only if his Codex row pairs a Claude model, otherwise change the Rob line to "Used by Rob" on GPT-6 Sol and drop or replace Sonnet's row. The chip rows in "How we run them" must sum to the model counts above. Why: counts are the only evidence the page offers.
2. **Simplify "How we run them".** Rename the label to "How we set them up" (sentence case, 13px, #8c8d91, no jargon caps list). Replace chip text "1M" with "1M context" and "high" with "high effort", and change the "with" color from #5a5a5a to #8c8d91. Why: unlabeled chips are jargon and the grey fails contrast.
3. **Remove the "Model." / "Tool." text prefixes** in the three takes rows (start with the sentence itself) and delete the "TOOL" tag next to the Claude Code card title. Tile shape carries the distinction, and the legend at the top already explains it. Reword the rows as "The reason most of us went back to Claude Code. 3 loves, 1 gripe about price."
4. **Fix palette.** Sep 2026 history card: change the `box-shadow:0 0 0 2px #9ce5f5` to `#f6b90f`, and add a small "Now" mono 12px label in yellow beside the date. Change the green dot #6ee7a0 and the coral dot to a neutral #8c8d91 dot or remove both dots (headings already say it). Why: sky blue is only for CTA / active filter / brand; coral is for stale or danger.
5. **Fix small text.** Bump the four take-initial badges from 11px to 12px mono uppercase-style (or drop the badges, since the name sits right beside them). Change the history arrows from #5a5a5a to #8c8d91. Replace the flat #5a5a5a circles in the history cards with the real model logos on light round tiles (20px), same as elsewhere.
6. **Delete the footnote** "Sample takes for this design..." (13px annotation at the bottom of Takes), and unify item-name size: use 16px/600 for names in Tools, Models, How we set them up and Takes rows (currently 17, 16 and 15).
