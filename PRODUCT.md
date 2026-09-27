# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users
AI power users who want a shareable record of the AI tools and models they actually use, per task. In v1 the door is Sign in with Every, so early members are Every staff and their circle. They claim a handle (`loadout.every.to/<you>`), tap their tools in about a minute, or let their own agent (Claude, Claude Code, Cursor, Codex) fill the loadout in over MCP. Every staff also browse the Every map.

## Product Purpose
Answer "What's in your AI loadout?": a profile of the tools and models a person uses for each task (coding, knowledge work, writing, research, classification, image, video, animation, text to speech, speech to text, music). Success is a member who has a complete loadout in about a minute and a link worth sharing.

## Positioning
The Every map: the most-used tools and models per category across real Every staff, who uses what, and what a member might be missing. A neighboring profile or link-in-bio product has no team's actual usage to aggregate.

## Operating Context
Members pick tools in the web UI or connect an agent at `/agents` with a normal sign-in (OAuth 2.1, no tokens to paste). Profiles can be made public, with a generated link-preview (OG) card. Every change to a loadout is kept with its date, so a later view can show who switched when a new model shipped. Members can add missing catalog items while picking; admins review them at `/admin/catalog_items`.

## Capabilities and Constraints
- The only production login is Sign in with Every. Locally, seeded members appear under "Dev login".
- One write path for loadouts (`Loadouts::Update`), shared by web pickers, MCP and WebMCP; history lives in `entry_changes`.
- Catalog is seeded from `config/catalog.yml`. Tool marks are typographic tiles, not third-party logos.
- Stack: Rails 8.1, Inertia, React 19, Tailwind 4, SQLite, Kamal. Deployed to `loadout.every.to`.
- Undecided: whether the product opens beyond Every sign-in, and any pricing or licensing.

## Brand Commitments
- Lives under every.to and signs in with Every; it should read as an Every product.
- Profiles are private by default; public is an explicit member choice.
- No engagement mechanics: no streaks, leaderboards or nudges. The dated history is a record, not a game.

## Evidence on Hand
- v1 screenshots in `docs/screenshots/` (landing, onboarding, editor, public profile, map, agents, share card).
- Seeded catalog and demo members. No real testimonials, customer counts or usage statistics exist; do not invent them.

## Product Principles
1. The member's real usage is the content; never pad profiles with aspirational tools.
2. Filling a loadout must take about a minute, by hand or by agent.
3. Private by default; sharing is deliberate.
4. The map earns its value from aggregate truth, not gamification.
5. Agents are first-class members of the workflow, on the same write path as people.

## Accessibility & Inclusion
No product-specific standard established.
