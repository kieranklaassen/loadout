# EveryConsent critique

Note: the Browser pane would not open a tab (tabs_create failed), so this is from source plus computed values, not a screenshot.

## Context
OAuth consent screen. A signed-in Every person is asked to let Claude Code write to their loadout. It is a trust decision: calm but high-stakes, and read once, quickly.

## First Impressions
Simple and right-sized: one 560px card, one question, one primary button. The copy is plain and the right scope is stated. The weak spots are the two things a trust screen must nail. The "can't" line is styled as the least important text on the card, and Deny is nearly invisible.

## Visual Design
**Deny disappears** — `.btn2` is #111111 fill with a 1px #2a2a2a border, sitting on a #111111 card. Fill matches the card and the border is the card's own edge colour (contrast about 1.3:1). Allow is solid sky blue, so Deny reads as a label, not a button. Both buttons are flex:1, so the width is equal, but the visibility is not. Keep Deny secondary, with a visible outline (#8c8d91) and #fdfaf7 text.
**The "can't" row is grey** — "It can't change who sees your page or delete anything." is #8c8d91 with no bold, while "Read" and "Add or change" are bold white. The guarantee that lowers risk is the quietest thing in the list. Make it the same weight as the others.
**Arrow glyph** — the "↔" between the tile and the Every logo is #5a5a5a on #111 (about 2.7:1). It is decorative, but it is dimmer than the muted floor.
**Type scale is fine** — 40 serif / 16 / 15 / 13, with nothing under 13px.

## Interface Design
**Who is asking is under-stated** — The requester is a 56px tile, and the name only appears inside the headline. The critical qualifier "redirects to localhost" sits in a 15px grey line, shared with "Signed in as Kieran Klaassen". "Redirects to localhost" is jargon and it hides the most security-relevant fact. We're missing an opportunity to say plainly: "Running on your computer".
**Undo is a dead phrase** — "You can revoke access any time on the Agents page." is 13px grey and unlinked. `.lnk` is defined but unused. Make "Agents page" a real link so the undo path is one click.
**No dead exits** — The header carries the wordmark link and the KK avatar link, which lead away from a pending decision. Deny and Allow both link to EveryAgents.dc.html, so Deny has no distinct outcome.

## Consistency & Conventions
Card, tile, button and mono conventions match the system. Sky blue is used only on the CTA and the italic brand word. The `.slot` and `.chip` CSS is dead weight. Two 13px muted notes (signed in, revoke) plus the footer repeat "Private by default" in a fourth voice.

## User Context
The user is cautious and wants to be reassured about limits before pressing Allow. The list order is good (Read, Add, then what it cannot do). The "cannot" statement should be as loud as the grants. "Nothing goes public without you" would also answer the actual fear, but it would add text, so the fixes below reuse the existing line.

## Top Opportunities
1. Give Deny a visible border and text.
2. Promote the can't line to full weight.
3. Replace "redirects to localhost" with plain language.
4. Make the Agents link real in the revoke line.
5. Point Deny somewhere other than EveryAgents.

---

## FIXES TO APPLY

1. **Make Deny clearly a button.** In `.btn2`, change `border:1px solid #2a2a2a` to `border:1px solid #8c8d91`, and keep `color:#fdfaf7`. Reason: it needs to be as reachable as Allow, and today it disappears into the card. Keep it secondary in fill; do not colour it.
2. **Promote the limit line.** On the third `<li>`, remove `color:#8c8d91` and change the text to `<b style="font-weight:600">Can't</b> change who sees your page or delete anything`. Reason: the guarantee reads like the grants, in the same voice and weight, in the same list.
3. **Plain-language origin line.** Change the `<p>` under the h1 to `Signed in as Kieran Klaassen · Running on your computer`. If `localhost` is semantically required, use "Sends you back to an app on this computer". Reason: "redirects to localhost" is jargon, and the safe reading is important to a wary user.
4. **Linked undo.** Change the bottom note to `You can turn this off any time on the <a class="lnk" href="EveryAgents.dc.html">Agents page</a>.` Keep 13px and #8c8d91, and #d0d0d0 for the link if the underline is kept. Reason: undo is one click, not a hint.
5. **Deny gets its own destination and the header stops offering exits.** Change the Deny `href` to `EveryHome.dc.html` (Allow stays on `EveryAgents.dc.html`). In the header, remove the `KK` avatar link, since "Signed in as" already names the user. Reason: the two buttons should not do the same thing, and there is no navigation on a decision screen. Also drop the unused `.slot`, `.chip`, `th`, `table` and `.row` CSS.
