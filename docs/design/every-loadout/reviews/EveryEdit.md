# EveryEdit critique

## Context
The "Rank your tools" editor. A signed-in Every person ranks up to three picks for one of 11 kinds of work, and may confirm picks an agent suggested. It is a routine, low-stakes task done once and revisited. The user wants to finish quickly and trust that it saved.

## First Impressions
It reads as a calm, well-ordered form and the Every dark language is followed closely. The three ranked slots are a clear focus. The weak spot is state: a confirmed pick and an agent-suggested pick look nearly identical. Both are full cards with the same four filled dropdowns, and only a 13px line at the bottom right differs. The eye goes to the sky-blue dashed slot 3 first, but the thing that needs a decision is the Confirm button in slot 2.

## Visual Design
**Yellow misused** — #f6b90f appears on "2 of 3 · 1 to confirm" in the sidebar and on "○ Suggested by your agent". The brief reserves yellow for NEWEST and rank-1. Here it means "pending". Use #d0d0d0 for the text and let the Confirm button carry the emphasis.

**Sky blue in four places** — the active-row outline, the dashed slot 3 with its heading and number, the Confirm button, and the Loadout wordmark. The dashed empty slot competes with the one real CTA. The empty slot should be quiet: a #3a3a3a dashed border and #d0d0d0 text. Sky stays on Confirm.

**Small muted text** — nearly all secondary text is 13px #8c8d91. Contrast is about 6.0:1 on #020202 and about 5.4:1 on #111, which passes, but the tool/model legend, "Saved just now", the field labels and the counts all sit at that one size and colour. The "Choose" placeholders are also #8c8d91 and look the same as labels.

**Type scale** — there are ten sizes: 12, 13, 14, 15, 16, 18, 19, 28, 40 and 56. Sidebar rows are 19px serif while the slot fields are 15px sans. Drop 19 to 18 and 16 to 15.

**Dead space** — about 90px sits between the last row and the footer. Fine, but the page is not dense.

## Interface Design
**Confirmed vs suggested is not distinct** — this is the biggest problem. Slot 2 should look provisional: a dashed #f6b90f-free border or a #8c8d91 dashed border, with the fields shown as agent-filled. Confirm should sit next to the pick, not below it at the far right beside Remove.

**Saving is unclear** — "Saved just now" implies autosave, but a suggested pick needs an explicit Confirm. Nothing says that changes are saved as you edit, or that a suggested pick is not yet on your profile. One line under the heading fixes it.

**Fields are not real controls** — TOOL, MODEL, CONTEXT and EFFORT are `<div>`s with a "▾" glyph, and the labels are `<div>`s, not `<label>`s. This is a mock, but the source cannot show focus, keyboard or select behaviour. Use `<label>` plus `<select>`, or a button with `aria-haspopup`.

**Redundancy** — three things say the same thing: the legend ("Tool: the app you use / Model: the AI behind it"), the TOOL and MODEL labels, and the two team columns. The legend can go. "Add as 3rd" on Codex duplicates the empty slot 3. The intro paragraph (35 words) repeats what the fields show.

**Team list is ambiguous** — "Try it" on GPT-6 Sol does not say which slot receives the model. A model needs a tool, so the action is unclear. Label it "Use in 3rd pick" or drop the button.

**Sidebar** — "3 of 3" and "Not started" on all 11 rows is a checklist. It edges toward completion pressure, which the brief avoids, and the row is 300px wide for a 13px status.

## Consistency & Conventions
Tool tiles are square and model tiles are round, and this holds throughout. Card treatments differ: slots use a box-shadow ring, the team list uses bare rows, and the agent card uses a ring with no border. Remove is a text link in slots, while Try it and Add as 3rd are `.btn2` buttons. The dashed slot 3 has no Remove or Skip, and it does not say what "optional" means for the tool field.

## User Context
The person feels guided but slightly unsure what counts. "Your first pick counts most" is clear. "Saved just now" is comforting. The person who most needs care is the one who did not make pick 2, an agent did, and the design lets them skim past it as if it were theirs.

## Top Opportunities
1. Make suggested visibly different from confirmed, and put Confirm beside the pick.
2. Drop yellow from status text and quiet slot 3 so sky blue means only the CTA.
3. Say what saves automatically and what waits for Confirm.
4. Remove the tool/model legend and clarify or remove the "Try it" and "Add as 3rd" buttons.
5. Use real labels and selects.

---

## FIXES TO APPLY

1. **Distinguish the suggested slot.** In slot 2 change the card style to `background:transparent;box-shadow:none;border:1.5px dashed #8c8d91`. Move the "Suggested by your agent" text and the Confirm button into the top row, right of the number "2" (a flex row ahead of the fields). Set the status text to `color:#d0d0d0` with no "○". Keep "Remove" at the bottom right. Why: the one pick that needs an action must not look finished.

2. **Take yellow off status text.** Sidebar Coding: change `#f6b90f` to `#d0d0d0` and shorten to "2 of 3 · 1 to confirm". "Suggested by your agent" also becomes `#d0d0d0` (see 1). Why: the brief reserves yellow for NEWEST and rank-1.

3. **Quiet the empty slot.** Slot 3: border `1.5px dashed #3a3a3a`. Number and "Add your 3rd pick" become `color:#d0d0d0`. Placeholders "Choose" stay `#8c8d91`. Sky remains only on Confirm, the active row and the wordmark. Why: one CTA per screen.

4. **State what saves.** Replace "Saved just now" with "Changes save as you go. Suggested picks stay private until you confirm." at 13px `#8c8d91`, under the "6 of 11 kinds started" line. Why: expectation-setting for auto-save vs Confirm.

5. **Remove the tool/model legend row** (the block with the two 18px tiles). The TOOL and MODEL labels and the team column headings already teach this. Also shorten the intro to "Pick your top three tools for each kind of work, and how you run them. Your first pick counts most. Skip any you like." (23 words). Why: fewer words, less clutter.

6. **Fix the team-list actions.** Change "Add as 3rd" to "Use as 3rd pick". Change "Try it" on GPT-6 Sol to "Use in 3rd pick" (same `.btn2`). Turn the four field labels into `<label>` and the field boxes into `<select>` with the same styling (`appearance:none` plus the existing "▾"). Why: says where each action lands, and forms need real controls.
