# EverySettings review

## Context
Account settings for one Every staffer or subscriber: edit name, link, a one-line bio, choose who sees their loadout, download history, delete. Calm, routine task, except the delete zone, which is high-stakes and irreversible.

## First Impressions
Clean, quiet and mostly on-brief: two columns, real inputs, serif section heads, one sky-blue CTA. But the page contradicts its own product rule. The visibility picker ships with "Every team" selected (sky-blue ring, the loudest thing on the page) while the footer says "Private by default." The delete card sits in the right column, separated and coral-bordered, yet its button is a fully lit solid coral fill with an empty confirmation box, so it looks armed.

## Visual Design
**Wrong default is the focal point** — the selected "Every team" card has a 2px #9ce5f5 ring; the other two have 1px #2a2a2a. The eye lands on a non-private choice. Default should be "Only me" so the highlight says "private."

**Delete button looks live** — solid #ff7765 fill with #121212 text, identical to an enabled state, while the input is empty. Coral is the heaviest fill on the page, heavier than the sky-blue Save. Danger should be quiet until earned.

**Delete card border is nearly invisible** — 1px #6b2c24 on #020202 is roughly 1.5:1. The zone reads as "a dim box," not "danger." The coral h2 (28px) does the work; the border adds noise.

**Delete card spacing broken** — the "Type your link to confirm" label sits directly under the paragraph with 0px gap (the label has no top margin); everything else on the page has 16-20px rhythm.

**Type sizes** — hint text is 13px #8c8d91 (about 5.9:1 on #0a0a0a, passes, meets the 13px floor). Radio descriptions are 14px #8c8d91. Fine. Labels are 14px/600 with field text 16px and nav 15px: five body sizes (13/14/15/16 plus 32/28/56 heads). The 28px vs 32px heading split is needless.

**Save far from the fields** — Save sits below the visibility list at y~1110 of 1180, only ~30px above the footer rule. Tight, and 500px away from Name.

## Interface Design
- Missing opportunity to show save state. Nothing says "Saved" or "Unsaved changes." Save is always sky blue, even with no edits. A short inline "Saved" beside the button after saving would close the loop.
- Missing opportunity to set expectations on Name: the hint says "From your Every account." but the field is an editable input. Either the user can change it or not. Make it read-only-looking, or drop the claim.
- The link field has no example of the result; "Changing it breaks old links." is a good warning but could name the effect ("every.to/loadout/kieran stops working").
- Bio textarea has no hint or limit; "One line" is asked for but the box is 96px tall (about 3 lines).
- Delete confirmation says "Type your link" but does not say what to type. Users will type the full URL and fail. Say: Type "kieran" to confirm.
- The visibility labels are good plain language. "Every team" is ambiguous (staff vs. subscribers?); "Anyone with the link" says "Public" while the link is already the identity, so the second sentence adds little.
- Right column below the delete card is empty (about 450px), left column crowds the footer. Layout is unbalanced but honest.

## Consistency & Conventions
Radio cards are custom spans, not real `<input type=radio>` (a11y and keyboard risk for the real build; fine for a mock). Save is a link, as with the other mock pages. Header, footer, nav match the other pages. Button hierarchy is right: btn (blue) primary, btn2 (grey) for download, coral for delete. Focus outline defined.

## User Context
The user is doing housekeeping, not creating. They want to feel in control of privacy. Showing "Every team" pre-selected makes them wonder if something was already shared. Uncommon care: a line under the picker stating who can see it right now, and a delete button that stays inert until the typed value matches.

## Top Opportunities
1. Default the picker to "Only me" so the page obeys "private by default."
2. Make delete inert (outlined, muted) until the confirm text matches; tell them exactly what to type.
3. Fix delete card spacing and give it a visible but calm border.
4. Add a Saved / Unsaved cue next to Save and pull Save closer to the fields.
5. Resolve the Name field contradiction and trim bio box to one/two lines.

---

## FIXES TO APPLY

1. **Select "Only me" by default.** In "Who can see it": move the selected styling (`box-shadow:0 0 0 2px #9ce5f5`, radio `border:5px solid #9ce5f5;background:#020202`) from the "Every team" label to the "Only me" label; give "Every team" and "Anyone with the link" the unselected styling (`0 0 0 1px #2a2a2a`, `border:1.5px solid #5a5a5a`). Why: the brief says private by default and the footer promises it; the loudest element must not contradict it.

2. **Make Delete look inactive until confirmed.** Change the "Delete my loadout" link from solid `background:#ff7765;color:#121212` to `background:transparent;color:#ff7765;border:1px solid #ff7765`. Keep it that way in the mock (the filled state applies only once the typed text matches "kieran"). Why: an empty confirmation with a fully lit red button reads as one click from disaster; the outline treatment lowers the accident risk and stops coral outweighing the Save CTA.

3. **Say exactly what to type.** Change the label "Type your link to confirm" to `Type kieran to confirm` (span in the label, keep 14px/600), and add `placeholder="kieran"` in the input styled with #8c8d91 (or leave the input empty and rely on the label). Why: "your link" is ambiguous (full URL vs. handle) and failed confirmations are frustrating at a tense moment.

4. **Fix delete card spacing and border.** Add `margin-top:20px` to the confirm `<label>` (currently 0). Change the card's `box-shadow:0 0 0 1px #6b2c24` to `0 0 0 1px #ff7765` at low emphasis via `border:1px solid rgba(255,119,101,.5)` (about 4:1 vs the page) and set the h2 to 28px to match 32px sibling heads only if consistent; simplest: make it `font-size:32px` like the other h2s. Why: consistent rhythm and heading scale, and the danger zone is clearly separate but not shouting.

5. **Add a save state and pull Save up.** Next to the Save button add a 13px #8c8d91 text: `Saved just now` (or `No changes yet`) as a span with `margin-left:16px;align-self:center` (wrap button + span in a flex row). Reduce the visibility section's `margin-top` from 40px to 32px, and the bio textarea height from 96px to 72px so Save clears the footer by at least 40px. Why: the user can tell whether their edit stuck, and the button stops crowding the footer rule.

6. **Fix the Name and Link hints.** Change "From your Every account." to "Shown on your page. Change it in your Every account." and make the input `readonly` styled `color:#d0d0d0;border-color:#2a2a2a`. Change the Link hint to "Changing it breaks old links to your page." Why: the editable-looking field currently contradicts its hint; plain language, one behavior per field.
