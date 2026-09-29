# EveryShare2 review

## Context
1200x630 link-preview image for a public profile (every.to/loadout/kieran). Seen at ~600px wide in a feed or chat unfurl, by a stranger deciding whether to click. Casual, glance-speed.

## First Impressions
The name is the hero and it works: 96px Newsreader with a sky italic "Klaassen" reads clearly at half size. The brand lockup (Every | Loadout) is recognisable. But the middle of the card is a row of six identical white squares that say nothing, and the only sentence that explains the product is 20px grey and drops to 10px in a feed. The collage on the right is atmospheric but is a temple with an hourglass, not a message.

## Visual Design
**Tool marks read as anonymous tiles** — Five 64px white squares: two logos (Claude Code, Claude), then the letters "M", "R", "M" in serif. The letters are placeholders, not marks; a stranger cannot tell they are AI tools. At 600px each tile is 32px and the logos are 18px glyphs. Real logos only, or fewer tiles.
**Tool/model distinction is absent** — Every tile is square. The headline names a model (Claude Opus 5.5) but no round tile exists, so the tools-square, models-round rule is not shown at all.
**Headline copy is unreadable small** — "#1 for Coding: Claude Code with Claude Opus 5.5" is 20px #d0d0d0, 10px at feed size. It is also the only proof this is about AI tools, and "Claude" appears twice.
**Dashed "+" slot** — A 1.5px dashed sky-blue add-slot is editor chrome. On a public card it implies an incomplete loadout and spends the sky accent on nothing. Sky is already used for "Loadout" and "Klaassen".
**Stacked mono URL** — every.to/loadout/kieran at 16px #8c8d91 is unreadable small, and repeats the brand from the lockup two lines above.
**Collage crop** — The 400px yellow panel shows a pediment and an hourglass, with the left third of the image sliding under the dark half (left:-560px). The yellow only appears as a thin strip on the right. The panel is 33% of the card yet carries no information; it competes with the name for weight.

## Interface Design
We're missing an opportunity to show one pick as the card's proof: the top pick (tool + model) as a single large unit next to its kind of work ("Coding"). Instead six equal tiles flatten the hierarchy and the real pick is buried in small text. Contrast: name (96px) then a tiny 20px line, with nothing at a middle size.

## Consistency & Conventions
Palette, fonts and sharp corners match the design language. The tile system does not: tools should be square logos, models round, and letter placeholders appear nowhere else in the product.

## User Context
A stranger sees a name and a nice picture, and cannot tell what Loadout is. The viewer who knows Kieran wants one answer: "what does he use for coding?" That answer should be readable without zooming.

## Top Opportunities
1. Promote the headline pick into a 28-32px line (or tile pair) that survives 50% scale.
2. Show one square tool logo plus one round model logo, drop letter placeholders and the dashed slot.
3. Reduce the collage panel or crop to the most iconic part; it should not fight the name.
4. Merge the URL into the lockup line.

## FIXES TO APPLY
1. **Make the pick readable.** Replace the 20px line with a 30px Hanken/Newsreader line: "Coding: Claude Code with Claude Opus 5.5" in #fdfaf7 (drop "#1 for", or keep "#1" as a yellow #f6b90f 30px mono prefix). Add margin-top 24px. Why: it is the message of the card and must be ~15px at feed size.
2. **Replace the six tiles with two.** Delete the "M", "R", "M" tiles and the dashed `.slot` "+". Keep tile 1 (Claude Code logo, square, 4px radius) and add a round tile (border-radius:50%, same #fdfaf7 bg, 64px) with the Claude/Opus mark; put them on the same row as the headline text, tile-then-text. Why: shows tools=square, models=round, and removes placeholder letters that convey nothing.
3. **Drop the URL line above the name** (`every.to/loadout/kieran`). Instead put it at the bottom-left at 18px #8c8d91 only if space remains; otherwise remove. Why: it duplicates the lockup and at 16px is illegible; removing lets the name sit clean.
4. **Narrow the collage and re-crop.** Set the right panel to 340px and change the img to `width:900px; left:-300px; top:0` so the hourglass sits in view with the yellow field visible at the top-right, and remove the left overlap. Why: less weight competing with the name, and the yellow (rank-1 accent) reads as intentional.
5. **Give the lockup room.** Increase "Loadout" to 36px and the Every logo to 30px; remove the 1px separator span. Why: brand recognition at thumbnail size is the second job of the card.
