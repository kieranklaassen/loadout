# EveryOnboarding review

## Context
First-run screen (step 1 of 2) for a new Every staffer or subscriber: pick a handle, choose who sees their loadout. Emotional state: curious, slightly wary about publishing opinions. Low stakes, but it is the first impression and the privacy question is the only real decision.

## First Impressions
Calm, legible, and short: one input, three choices, one button. The layout fits (button bottom ~790px, footer rule ~835px, about 45px clear). The problem is that the right column shouts louder than the left. Four dashed sky-blue boxes reading "Your 1st pick" out-glow the single sky-blue CTA, and the form the user must act on is visually equal to a decorative preview.

## Visual Design
**Sky blue is spent nine times** — Sky is on: the italic brand word (header and footer), the nav underline, the input border, the selected radio, the selected card ring, four dashed slots, and the CTA. The brief allows it only for the CTA, active filter and brand word. The four slots (1.5px dashed #9ce5f5, bold 13px sky text) are the worst offenders, because they are the largest sky area and they are not actions. Make them neutral (dashed #3a3a3a, text #8c8d91).

**Off-palette green** — The availability dot is #6ee7a0, a colour no other rule allows. A 9px dot alone carries the state, with text in white beside it. Use a check glyph or plain text in #fdfaf7; the sentence already says "available".

**Type is mostly sound** — Sizes 56/32/18/17/16/14/13/12 are a lot of steps for one screen, but hierarchy reads. Muted #8c8d91 on #020202 is about 6:1 and on #111111 about 5.4:1, so the 14px option descriptions and 13px caption pass. The 12px mono step label is at the floor.

**Empty space under the preview** — Preview card ends near y=570; the column is blank to the footer while the left is packed. Fine, but the card has no reason to be four rows tall.

## Interface Design
**The preview does not earn its space** — It shows only 4 of 11 kinds of work with "Your 1st pick" repeated 4 times (16 words of the same string). It never reflects the visibility choice, and the footnote "Empty slots stay hidden from others until you fill them" sits next to "Only me" selected, which confuses: hidden from whom, if nobody sees it? The one useful thing it shows is the link and name updating live. That needs a header, not four empty rows.

**Fake controls** — The radios are styled `<span>`s (no `<input type=radio>`, no name, no checked state), so keyboard, screen readers and Rails form posts cannot work. The link `<input>` has no name, type, autocomplete or aria-describedby for the availability line. The CTA is an `<a>`, not a submit button. This is a mock, but the source should model the real thing.

**Expectation setting** — Good: "You can change it later in settings", "This is the default", and the step label says what comes next. Missing: no note on what characters are allowed, and "Every team" is vague (staff only? subscribers?).

**Escape hatches on a first-run screen** — Full nav (Home, Your loadout, Agents, Settings) plus avatar shows, with "Your loadout" marked current on a page that is not it. Six exits compete with the one path.

## Consistency & Conventions
Card, tile and button styles match the other pages. Handle field with live availability follows the GitHub/Substack convention. Inconsistency: the selected option uses a 2px sky ring, the input a 1px sky border, and the unselected cards a 1px grey ring, so selection is three different strokes.

## User Context
The user feels reassured on privacy (default stated, green light on the handle) but nudged by the preview to fill things in now, which drifts toward the engagement nudge the brief forbids. Uncommon care would be showing the preview title change with the visibility choice ("Only you can see this") instead of a generic footnote.

## Top Opportunities
1. Make the slots neutral so the CTA is the only sky action.
2. Use real radios and a real input with name and submit.
3. Strip the header nav to logo and avatar on this screen.
4. Shrink the preview to what changes: name plus link plus two quiet slots.
5. Replace off-palette green.

---

## FIXES TO APPLY

1. **Neutralise the preview slots.** In `.slot` change `border:1.5px dashed #9ce5f5;color:#9ce5f5;font-weight:600` to `border:1px dashed #3a3a3a;color:#8c8d91;font-weight:400`. Why: sky is reserved for the CTA/active/brand; four sky boxes currently outweigh the button.

2. **Cut the preview to 2 rows and one line of copy.** Delete the Video and Image rows (keep Coding, Writing). Change slot text from "Your 1st pick" to "Empty". Replace the footnote with "Only you can see this." (matches the selected "Only me" default). Why: repeated identical strings are noise; the card's job is to show name plus link, and it no longer suggests 4 things to do now or contradicts the privacy choice.

3. **Make the header quiet on first run.** Remove the Home, Your loadout, Agents and Settings links (keep logo and the KK avatar). Why: the current-page underline is wrong here, and four exits compete with the single next step. Also removes one sky use.

4. **Use real form controls.** Replace the three radio `<label>`s' span-circles with a visually hidden `<input type="radio" name="visibility" value="private|team|public">` (private `checked`) and style the card ring from the `:checked` sibling; give the handle input `name="handle" type="text" autocomplete="off" aria-describedby` pointing at the availability line's id; make the CTA a `<button type="submit">` styled with `.btn`, wrapped in a form (keep the visual output identical). Why: accessibility and the real Rails form post.

5. **Recolour the availability signal.** Change the dot `#6ee7a0` to a "✓" glyph in `#fdfaf7` (keep the 14px text). Why: keeps within the palette while staying distinguishable from an error state (coral text in the unavailable state).

6. **Unify selection strokes and clarify "Every team".** Make the input focus border and the selected option ring both `2px` (`box-shadow:0 0 0 2px #9ce5f5` on the input wrapper instead of border) and change the "Every team" description to "Everyone on the Every team can see it." Why: one selection stroke; plain, unambiguous language.
