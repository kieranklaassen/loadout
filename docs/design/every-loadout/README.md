# Every Loadout design source

Design of record for the Every Loadout redesign. Made in a Claude Design canvas
(https://claude.ai/artifact/TQDh5i7sMNsFgn9u6A31wa, private) and exported here so
the implementation has a durable reference.

- `pages/*.dc.html` are the eleven page mocks, one per screen. Each is a static
  design, 1440px wide (share card 1200x630): Home, Kind of work, Person view,
  Profile, Rank your tools, Claim your link, Sign in, Agent consent, Agents,
  Settings, Share card. `/_blob/<id>` image URLs are canvas assets; use
  `assets/` instead (`assets/logos/M_*.svg` are single-colour tool and model
  marks from Simple Icons; `every-logo.svg` and `every-collage.jpg` are Every's).
- `DESIGN-BRIEF.md` is the shared brief: product rules and the design language
  (colors, type, tool = square mark, model = round mark, spacing, minimum sizes).
- `reviews/` holds the per-page critiques and what each fix changed.

All names, counts, dates and quotes in the mocks are placeholder data.
The takes on the Kind of work page are sample copy; real takes come from Checks
(checks.every.to, sign-in gated) and Vibe Checks (every.to/vibe-check/...).
