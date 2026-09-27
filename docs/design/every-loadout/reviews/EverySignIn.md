# EverySignIn review

Note: the browser tab cap was reached, so I could not open my own tab (I did not touch other agents' tabs). This review is from the source plus computed geometry, not a screenshot.

## Context
Sign-in gate for Every Loadout, 1440x900. Visitors are Every staff and subscribers who arrive from a link, plus curious outsiders. Routine, low-stakes, and should take one click.

## First Impressions
Clear and calm: one headline, one button. But the right side is a 560x560 solid yellow (#f6b90f) slab, the heaviest object on the page. It outweighs the 17px sky-blue button, and the brief reserves yellow for NEWEST/rank-1 accents. The button says "Continue with Every" under a headline that says "Sign in with Every", so the page uses two names for one action.

## Visual Design
**Yellow slab steals the focus** — 560x560 of #f6b90f is about 44% of the content width. The eye lands on the art first, then the headline, then the button. Shrink the art or drop the solid fill so the button is the only saturated action.

**Type scale is crowded** — sizes used: 64, 28 (wordmark), 19, 18 (footer wordmark), 17 (button), 14, 13. Seven sizes on a page with five pieces of copy. The 19px and 17px are near-duplicates. Use 64 / 18 / 14.

**Underline color** — `.lnk` underline is #5a5a5a on #020202, about 2.8:1, so the links are weakly signalled. The text is #fdfaf7 and readable. Use #8c8d91 for the underline, which is about 6:1.

**Muted text passes** — #8c8d91 on #020202 is about 6:1. It is fine at 14px and 13px.

## Interface Design
**Two names for one action** — the h1 says "Sign in with Every", the button says "Continue with Every". Users scan for the button that matches the headline.

**Who can sign in is vague and ungrammatical** — "Every team members and subscribers can rank their AI tools..." should read "Every team members" as "Members of the Every team". It also never says what happens to outsiders who try the button. Say it plainly.

**Redundant privacy copy** — "Your loadout is private until you make it public" (14px, under the button) and the footer "Private by default. Public when you want." say the same thing. The footer also shows the Every logo + "Loadout" + "every.to/loadout", which repeats the header brand. Two of the three footer items can go.

**Dead-end links** — "Join Every" and "read the team's page" both link to EveryHome. "Join Every" should go to every.to (subscribe), or it promises something it does not do.

**Header for signed-out visitors** — the `<nav>` is empty, which is correct because the main nav shows only when signed in. The logo links home, so the header works. Remove the empty `<nav>` element, since an empty landmark is noise for screen readers.

## Consistency & Conventions
Sharp 2px button, Newsreader h1 with the italic sky "Every", and the Hanken body all match the language. Sky blue is used only for the CTA and the brand word, which is correct. The `.btn` inline padding/size override is the only one-off.

## User Context
The user wants to get in, not read. Reassurance about data ("only read your name and photo") is the right thing to say, but it is buried at 14px muted. Uncommon care would put that line at 14px #d0d0d0 directly under the button and cut everything after it.

## Top Opportunities
1. Match button text to the headline.
2. Cut the art's weight so the button leads.
3. Rewrite the explainer to name team / subscribers / everyone else in two short sentences.
4. Remove the duplicated privacy line in the footer.
5. Fix links and the underline contrast.

## FIXES TO APPLY

1. **Button label = headline.** Change the button text "Continue with Every" to "Sign in with Every". Why: one name for one action; users match the button to the headline.

2. **Rewrite the explainer paragraph** (currently "Every team members and subscribers can rank their AI tools and see what the team uses. Anyone else can read the public page without signing in.") to: "Members of the Every team and Every subscribers can sign in to rank their AI tools. Everyone else can still read the team's public page." Keep 19px -> change to 18px, color #d0d0d0. Why: names the three groups plainly and fixes the grammar.

3. **Reduce the art's weight.** Change the yellow container from 560x560 to 480x480 and keep `align-self:flex-start` (so it top-aligns with the h1 area), scale the inner img width to about 860px. Widen the left column's gap accordingly (keep 72px). Why: the yellow slab currently outranks the CTA; a smaller block lets the button lead and stays within the collage-art exception for yellow.

4. **Remove footer duplication.** In the footer, delete the Every logo `<img>` and the "Loadout" italic span; keep only the mono "every.to/loadout" on the left and delete the "Private by default. Public when you want." span (the same claim sits under the button). Why: the header already carries the brand, and the privacy claim is stated once next to the action.

5. **Fix links and small text.** (a) Point "Join Every" to a real Every page (every.to) instead of EveryHome.dc.html; keep "read the team's page" -> EveryHome. (b) Change `.lnk` `text-decoration-color` from #5a5a5a to #8c8d91. (c) Delete the empty `<nav ... aria-label="Main"></nav>` in the header. Why: honest link target, links visible at a readable contrast, no empty landmark.
