# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users
Every staff and their circle: people who use AI tools every day and want to see which tools and models the team relies on, and to share their own picks. In v1 the door is Sign in with Every. A member claims a link (`toolbox.every.to/<you>`), ranks up to three picks per kind of work in about a minute, or lets their own agent (Claude, Claude Code, Cursor, Codex) propose picks over MCP and confirms them on the site. Visitors and other Every accounts read only what people chose to share with them.

## Product Purpose
Answer "Which AI tools does Every use?" for each kind of work (coding, knowledge work, writing, research, classification, image, video, animation, text to speech, speech to text, music), and "What's in your AI toolbox?" for one person. Success is a member with a complete ranked toolbox in about a minute, and a team page that stays true because it counts only people who chose to share.

## Positioning
"The AI tools Every uses": a dark, Every-branded page of the tools and models real Every staff use for each kind of work, counted as plain "N of M" people. A neighboring profile or link-in-bio product has no team's actual usage to aggregate.

## Operating Context
Home is the same page for everyone, read as the viewer: up to three latest model launches, a table of the most used tool and model per kind of work with counts and last update, an Overall top 10, SHOW and PERSON filters, and search. A Kind page (`/kinds/<kind>`) shows who ranks each tool and model 1st, 2nd and 3rd, the setups people share, links out to Vibe Checks, and "What we used before" once the team's number one has changed. A profile (`/<handle>`) shows one person's ranked picks and can be compared with yours.

Members rank in the Rank editor or connect an agent at `/agents` with a normal sign-in (OAuth 2.1, no tokens to paste). An agent can only suggest picks: a suggestion is visible to its owner alone until they confirm it on the site. Every change to confirmed picks is kept with its date, which feeds the team's history. Members can add missing catalog items while picking; admins review them, and set model launch dates and Vibe Check links, at `/admin/catalog_items`.

## Capabilities and Constraints
- The only production login is Sign in with Every. "Every team" means a verified `@every.to` email. Locally, seeded members appear under "Dev login".
- Picks are ranked: up to three per kind of work, each a tool plus an optional model, context size (200K, 1M) and effort (low, medium, high). A tool appears once per kind. Tools and models are counted separately.
- Three visibility levels: Only me (the default), Every team and Anyone with the link. One rule decides who may open a page, and every count, name, search hit, PERSON option, profile and share card follows it. Narrowing takes effect at once, and a hidden page answers exactly like a handle nobody claimed. A share card already unfurled elsewhere cannot be recalled.
- The counting rule: "N of M". M is the people in the selected SHOW group (Every team, or everyone else) whom the viewer may open and who have at least one confirmed pick; N is the people among them who have the item. Only people who chose to share are counted, plus your own picks with a note when they are private. Suggestions and pending catalog items count nowhere. "Every subscribers" is a disabled option: there is no data source yet.
- Tools show a square mark and models a round one: the real single-colour mark where the catalog has one, otherwise the first letter of the name in the serif face. No typographic tiles.
- One write path for toolboxes (`Toolbox::Update`), shared by the web editor, MCP and WebMCP. Agents may run only `suggest` and `withdraw`; history lives in `entry_changes`.
- Catalog is seeded from `config/catalog.yml` and synced on every deploy. Launch dates and Vibe Check links are admin-owned.
- Look and feel: "Every dark" (near-black page, #111111 panels, Newsreader headings, Hanken Grotesk UI, Geist Mono captions, all fonts self-hosted). The design of record is `docs/design/every-loadout/`.
- Hosts are configurable: `PUBLIC_BASE_URL` is the one setting, and `toolbox.every.to` is the default display host. Moving to `every.to/toolbox` is a separate deploy task.
- Stack: Rails 8.1, Inertia, React 19, Tailwind 4, SQLite, Kamal.
- Undecided: whether the product opens beyond Every sign-in, any pricing or licensing, and where an Every subscribers audience would come from.

## Brand Commitments
- Lives under every.to and signs in with Every; it should read as an Every product.
- Private by default: a page is Only me until the member chooses Every team or Anyone with the link.
- No engagement mechanics: no streaks, points, medals, leaderboards of people or nudges. Counts are people ("5 of 6 use it"), never scores. The dated history is a record, not a game.

## Evidence on Hand
- The design source in `docs/design/every-loadout/`: eleven page mocks, the brief and the critiques. Names, counts, dates and takes in the mocks are placeholders and never ship as data.
- The marketing screenshots in `docs/screenshots/` (landing, onboarding, editor, public profile, map, agents, share card) are v1 and predate the redesign. Regenerating them is follow-up work.
- Seeded catalog and demo members; development launch values are labelled as demo. No real testimonials, customer counts or usage statistics exist; do not invent them.

## Product Principles
1. The member's real usage is the content; never pad a page with aspirational tools.
2. Filling a toolbox must take about a minute, by hand or by agent.
3. Private by default; sharing is deliberate, and a count only ever includes people who chose to share.
4. The team page earns its value from aggregate truth, not gamification: counts of people, never scores.
5. Agents propose, people decide. An agent's pick is a suggestion until its owner confirms it on the web.

## Accessibility & Inclusion
No product-specific standard established beyond the design brief's minimum text sizes (12px for uppercase mono labels, 13px for everything else), enforced by a test.
