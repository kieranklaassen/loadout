## Context
Setup page where an Every person connects an AI agent (Claude, Claude Code, Cursor, Codex) to fill in their Loadout, and manages connected agents. Calm, low-stakes, but Revoke touches trust and access.

## First Impressions
Clean and quiet, on-brand. The order is right: promise, prompt, four connect cards. But the page has two jobs (connect, manage) and the second is squeezed into the right rail under a safety box. The commands, which are the whole point, are the smallest and greyest things on the page. The connected state is not visible where you connect.

## Visual Design
**Commands break mid-word** — `word-break:break-all` in 13px mono makes "loadou / t" and "lo / adout/mcp" (Cursor) wrap inside words. Copying by eye is error-prone. Use `overflow-wrap:anywhere` so it breaks only at slashes/spaces, or allow a single-line horizontal scroll.
**Command text is dim** — #d0d0d0 on #020202 is fine for contrast (~14:1) but at 13px it reads as a caption, not the action. Use #fdfaf7.
**Two of the four boxes are not commands** — Claude ("Settings → Connectors → ...") and Cursor ("Add to Cursor, or paste {...}") sit in the same black mono well as real shell commands, so it looks copyable when it is a mix of steps and a JSON blob. The Cursor box is the worst: prose and JSON run together.
**Heavy stroke stack** — every block (prompt, 4 cards, safety box) uses the same #111 + 1px #2a2a2a box, 6 boxes of equal weight plus a black inset inside each card. Nothing says "start here" except the H1.
**Inconsistent widths** — prompt box 640px, grid 760px, intro paragraph 600px: three right edges on the left column, none aligning with anything.

## Interface Design
- No focusing mechanism after the H1: the example prompt (24px serif, the clearest text) competes with the four cards, and its label "THEN ASK IT" is 12px #8c8d91, easy to skip. The prompt is not copyable either.
- We are missing an opportunity to show connection state on the cards: Claude Code and Cursor are connected but their cards look identical to Claude and Codex. Connected state lives only in the right rail, 400px away.
- **Revoke is unsafe and unclear**: identical style to a neutral button, no consequence text, and it links to the same page (no confirm). Should read as a deliberate action (coral text is allowed for danger), and say what it does.
- "Cursor · never used" is useful, but "Connected Sep 12 · used 2 days ago" wraps to two lines at 13px in a 250px column.
- Safety box has 4 bullets; the third ("Its picks show as suggestions until you confirm them") is the key trust line and is buried. There is no copy/"Copy" affordance on any command.
- Tools vs models: correct, agents are named as tools (tiles are square), no model confusion. "Claude" vs "Claude Code" needs one clause since both are Anthropic tools.

## Consistency & Conventions
Square light tiles are used correctly for tools. Nav matches other pages. The footer "Private by default. Public when you want." repeats the brand voice well. Copy is plain except "picks", "MCP" appears only inside commands, fine. "Your normal Every sign-in. There are no keys to paste" is good.

## User Context
The person is curious and slightly wary ("what will it do to my profile?"). Answer to that fear sits in the right column, after the cards. Uncommon care: a Copy button per command, plain "Revoke" consequences, and the connected badge on the card they just used.

## Top Opportunities
1. Make commands wrap safely and readable, plus a Copy affordance.
2. Make Revoke deliberate and explain it.
3. Show "Connected" on the matching card.
4. Lead the safety box with the suggestion-until-confirmed line.
5. Align the left column to one width.

## FIXES TO APPLY
1. Command wells: replace `word-break:break-all` with `overflow-wrap:anywhere` on all four `.mono` boxes; set text color to #fdfaf7. Add a right-aligned "Copy" text link (13px Hanken, #9ce5f5 NOT used; use #d0d0d0 underlined, `.lnk` style) on the card header row for Claude Code and Codex, the two real one-line commands. Why: readable, copyable, no broken words.
2. Cursor card: split into two lines inside the well: "Add to Cursor" as a normal-weight line, then the JSON `{"mcpServers":{"loadout":{"url":"https://every.to/loadout/mcp"}}}` on its own line. Same for Claude: shorten to "Settings → Connectors → Add custom connector" then the URL on the next line. Why: steps vs. copyable value are distinct.
3. Revoke: color text coral #ff7765, keep `.btn2` shape, add a 13px muted line under each agent name "Revoking stops it reading or changing your loadout." only once (under the "Connected agents" H2, not per row). Point href to a confirm state (e.g. `EveryAgents.dc.html#revoke`) rather than the page itself. Why: danger is coral per brief; consequence is stated once without clutter.
4. Connected marker: on the Claude Code and Cursor cards add, on the right of the header row, a 12px mono "CONNECTED" in #fdfaf7 (no color, no dot, not sky blue). Why: obvious which agents are connected without leaving the card.
5. Reorder the safety list so "Its picks show as suggestions until you confirm them." is first, and merge bullets 2+3 into one: "It can add or change picks, shown as suggestions until you confirm them." Drops to 3 bullets. Why: simpler, trust line first.
6. Alignment: set the intro paragraph, prompt box and card grid all to `max-width:760px`, and make the prompt label "THEN ASK IT" #d0d0d0 (still 12px mono). Fix the connected row's "Connected Sep 12 · used 2 days ago" to fit one line by dropping "Connected" ("Sep 12 · used 2 days ago"). Why: one clean left column; no wrapped meta.
