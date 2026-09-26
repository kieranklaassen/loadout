# Pattern survey: .claude/ and CLAUDE.md conventions

Surveyed: `~/cora`, `~/atelier`, `~/tada`, `~/diskman`, `~/lifegarden`, `~/thinkroom`, `~/riffrec-dashboard`, `~/kieranklaassen-com`, `~/leva`, `~/every`, `~/erf-rails`, `~/blazer-ai`.

## 1. Dominant pattern

Across the newer, actively-developed apps (thinkroom, riffrec-dashboard, kieranklaassen-com, atelier, tada, cora), a single house convention shows up over and over: **`AGENTS.md` is the real file and `CLAUDE.md` either symlinks to it (`CLAUDE.md -> AGENTS.md`) or is a one-line pointer (`@AGENTS.md`)** — the content is written once, agent-tool-agnostic. These files are short-to-medium (25–376 lines), written in dense prose (not bullet-soup), and organize around **operational knowledge a fresh agent session needs immediately**: `bin/dev`/`bin/setup` commands, the git-workflow guardrail ("never push/commit to main"), a "Documented knowledge" section pointing at `docs/solutions/` (bug fixes and best practices as individually-dated Markdown files with YAML frontmatter: `module`, `tags`, `problem_type`) and, where present, `CONCEPTS.md` (a glossary of project-specific domain vocabulary). Kamal deploy notes and a "read `DEPLOYING.md` first" pointer appear whenever the app deploys with Kamal. riffrec-dashboard explicitly names thinkroom as its bootstrap sibling and codifies a "match thinkroom where free, take framework defaults otherwise, never port a workaround without its cause" tiebreaker rule — i.e. these files are lineage-aware, not written from scratch each time. Older / one-off / generated-from-a-generic-template projects (every, erf-rails, blazer-ai, leva) instead have a single flat CLAUDE.md in the default "This file provides guidance to Claude Code..." shape with tech-stack bullets and command lists — no `docs/solutions/`, no `CONCEPTS.md`, no symlink convention. `.claude/` directory contents (custom subagents, slash commands, hooks, `settings.json` permission allowlists) are sparse and only fully fleshed out in one project (cora); everywhere else `.claude/` is empty, absent, or holds only vendored skill packages (`inertia-rails-*`) and a `launch.json`.

## 2. Per-project breakdown

### cora
- `CLAUDE.md` (376 lines) + `AGENTS.md` (81 lines) — two **separate** files, not symlinked, with different audiences: CLAUDE.md is the full house style guide (git worktree setup, fake Gmail dev mode, Ruby Native iOS wrapper integration, Hugeicons icon convention, Flipper shadow-mode rollout pattern, large-table migration rules, Stimulus JSDoc convention, VCR testing practices); AGENTS.md is a shorter "Cursor Cloud" environment-setup + required-skills-workflow doc (`ce-work` → `ce-simplify-code` → `ce-code-review` → `ce-compound` → PR).
- `CONCEPTS.md` present at repo root — domain glossary (Brief, Briefed, Focus, Email Processing State, Inbox Draft, Sent reply convergence), explicitly says it "accretes as ce-compound and ce-compound-refresh process learnings."
- `docs/solutions/` present, organized by category, YAML frontmatter (`module`, `tags`, `problem_type`).
- `.claude/settings.json` — permission allowlist (`Bash(bin/rails:*)`, `Bash(bundle exec standardrb:*)`, `WebFetch(domain:github.com)`, etc.) + a `PreToolUse` hook on `Bash` running `.claude/hooks/block-main-push.rb`.
- `.claude/hooks/`: `block-main-push.rb` (blocks `git push origin main` patterns, exits non-zero to block the tool call), `run-linter.rb` (runs `standardrb --fix` + `erb_lint --autocorrect` on `git commit`, warns via stderr but never blocks).
- `.claude/agents/` — 4 custom subagents: `ahoy-tracking-expert`, `appsignal-log-investigator` (model: sonnet, huge allowed-tools list incl. AppSignal/GitHub/Stripe/Todoist MCP), `assistant-component-creator`, `cora-test-reviewer`.
- `.claude/commands/` — `update-help-center.md` (syncs `docs/help-center/cora-complete-guide.md` from recent commits) and a `product-marketing/generate-changelog.md`.
- `.claude/skills/` — vendored `inertia-rails-*` skill set (ssr, testing, setup, cookbook, forms, performance, auth, best-practices) plus project-specific skills (`figma-pixel-perfect`, `cursor-cloud-agent`, `alpha-feedback-pulse`).
- `.claude/worktrees/` — active git worktrees live inside `.claude/`, each a full checkout with its own `CLAUDE.md`/`AGENTS.md` copy.
- Kamal: `config/deploy.yml` present but **unedited template** (`service: my-app`, `image: your-user/my-app`) — Cora is not actually deployed via this file.
- File-based todo tracking system in `todos/` (not committed) with `{issue_id}-{status}-{priority}-{description}.md` naming and a dedicated `file-todos` skill.

### atelier
- `CLAUDE.md` only (130 lines, no AGENTS.md, no symlink) — dense, ADR-referencing ("D32", "D54" decision numbers scattered inline).
- `CONCEPTS.md` present (77 lines) — glossary for the to-do backlog domain (To-do, Canonical Id, Resolution).
- `docs/CONVENTIONS.md` (8 lines) — a short separate hard-rules file: "Rails renders and prompts; it never owns durable agent lifetime, PTYs, or child processes," etc.
- Notable: a **"Documents — what each is, and when to reach for it" section** in CLAUDE.md mapping every doc (`README.md`, `STRATEGY.md`, `CONCEPTS.md`, `docs/vision.md`, `docs/prd.md`, `docs/design-system.md`, `docs/decisions.md`, `docs/runbooks/`, `docs/iteration-log.md`, `docs/open-questions.md`, `docs/compound-engineering.md`, `docs/plans/`, `docs/skills/`, `docs/solutions/`) to when an agent should read it — explicitly says "keep this map current... it's how knowledge compounds here."
- `docs/skills/` — plain instruction Markdown files preloaded verbatim into agent panes by seeded prompt (explicitly **not** Claude Code `SKILL.md` packages).
- `docs/solutions/` present, subcategorized (`architecture-patterns/`, `tooling-decisions/`), same YAML-frontmatter shape.
- `.claude/` has only `skills/` (vendored `inertia-rails-*` set), `launch.json`, `scheduled_tasks.lock` — no settings.json, no agents, no commands, no hooks.
- No `config/deploy.yml` (not present) — Atelier runs as a local launchd appliance (`com.kieran.atelier`), not Kamal-deployed.

### tada
- `CLAUDE.md` is literally one line: `@AGENTS.md` (the file-reference/import convention).
- `AGENTS.md` (103 lines) is the real doc: tech stack line, "Verify before you're done" (`bin/rails test`, `npm run check`, `bin/rubocop`), git workflow (never commit to main, feature-branch-and-PR), a "Where to look" section pointing to `docs/cartridges.md`, `docs/native.md`, `docs/plans/` (R-numbers/KTD-numbers), `docs/strategy/`; an i18n contract section (`docs/i18n.md`); a "Hard rules" section with numbered rules (R23 license, R15 no engagement mechanics for kids, R20 no egress); Cursor Cloud environment notes.
- No `CONCEPTS.md`, no `docs/solutions/` at top level (has `docs/residual-review-findings/` instead).
- `.claude/skills/` — two project-specific skills (`image-factory`, `cartridge-creator`) plus a plain-file `.claude/ruby_native.md` — no vendored inertia skills here.
- `config/deploy.yml` present and Kamal-active (per `docs/plans/*-feat-kamal-deploy-app-tada-computer-plan.md`).

### diskman
- No `CLAUDE.md`; `AGENTS.md` only (63 lines), Cursor-Cloud-flavored (architecture, `bin/dev`, credentials setup, SQLite database location, testing/linting commands, key gotchas). No `.claude/` custom content beyond an empty `worktrees/` dir.
- No `CONCEPTS.md`, no `docs/solutions/`.
- `config/deploy.yml` present, static: `service: diskman`, `image: kieranklaassen/diskman`, `servers.web: [cora-hetzner]` — deployed to the same shared Hetzner host as other projects.

### lifegarden
- **No `CLAUDE.md` and no `AGENTS.md` at all** — explicitly absent, unlike every other Rails project surveyed.
- `.claude/` exists but holds only an empty `worktrees/` directory.
- `docs/` has `plans/`, `runbooks/hetzner-deployment.md`, `dogfood-reports/` — no `solutions/`, no `CONCEPTS.md`.
- `config/deploy.yml` present, static `service`/`image: kieranklaassen/lifegarden`, deployed to `cora-hetzner`.

### thinkroom
- `CLAUDE.md` is a **symlink** to `AGENTS.md` (`lrwxr-xr-x CLAUDE.md -> AGENTS.md`) — the cleanest instance of the symlink convention. 25 lines total.
- Sections: "Local development and review" (bin/dev, Cloudflare tunnel caveats, Vite `skipProxy` must stay disabled), "Deploying" (Kamal, hosts `thinkroom.kieranklaassen.com` / `pruf.kieranklaassen.com`, points to `DEPLOYING.md`, notes worktrees don't inherit `.kamal/deploy.env`/`.kamal/secrets`/`config/master.key`), "Documented knowledge" (`docs/solutions/` YAML-frontmatter convention, `docs/plans/`, `CONCEPTS.md` "when present"), Cursor Cloud environment notes.
- `docs/solutions/` present; `DEPLOYING.md` present at repo root.
- `.claude/` has no settings.json, no agents, no commands — only `worktrees/`.
- `config/deploy.yml` is env-driven: `service: <%= ENV.fetch("KAMAL_SERVICE") %>`, `image: <%= ENV.fetch("KAMAL_IMAGE") %>`, hosts from `ENV.fetch("KAMAL_HOSTS")` split on comma — a reusable template rather than hardcoded values.

### riffrec-dashboard
- `CLAUDE.md -> AGENTS.md` symlink, same as thinkroom. `AGENTS.md` is by far the longest of the survey (370 lines / 23.5KB) — a dense architectural narrative (auth-gate fail-closed rules, credential ladder across 4 different secret types with different treatments, CORS rationale, Solid Queue in-Puma rationale with "four things load-bearing and fail silently if undone," CI master-key gotcha).
- Explicitly states "Conventions follow `~/thinkroom`, which is the sibling app this was bootstrapped from" and has a **dedicated "Three durable rules" section** including "**1. The tiebreaker.** Match thinkroom where it costs nothing. Take framework defaults otherwise. Never port a workaround without its cause" — with a worked-examples list of what was and wasn't ported from thinkroom.
- "Documented knowledge" section: `docs/plans/` filename convention `YYYY-MM-DD-NNN-<type>-<slug>-plan.md`, `docs/solutions/` with frontmatter (`title`, `module`, `date`, `problem_type`, `component`, `tags`, `applies_when`).
- `docs/solutions/migrations/` sample file confirms the frontmatter shape in practice.
- `config/deploy.yml` is the same env-driven Kamal template as thinkroom (`KAMAL_SERVICE`/`KAMAL_IMAGE`/`KAMAL_HOSTS`), deployed alongside "four other live production apps behind one shared kamal-proxy" on the same host.
- `bin/ci` is the single-command gate (`bin/rubocop`, `npm run check`, `bin/rails test`, `bin/brakeman`, `bin/bundler-audit`), kept in step with `.github/workflows/ci.yml`.
- No `.claude/` directory found at all (not even empty).

### kieranklaassen-com
- `AGENTS.md` only (32 lines), **no `CLAUDE.md` and no symlink** — the one project where AGENTS.md exists standalone without a CLAUDE.md pointer.
- Sections: "Local development and review" (bin/dev, Vite skipProxy, content authoring rules for `content/posts/` frontmatter and `ai_assisted: true` flag), "Deploying" (Kamal 2.12, `.kamal/deploy.env` gitignored), "Architecture" (Rails owns routes/props, no parallel JSON API, global Inertia SSR, browser-only work in effects).
- `config/deploy.yml` uses the same `KAMAL_SERVICE`/`KAMAL_IMAGE`/`KAMAL_HOSTS` env-driven template as thinkroom/riffrec-dashboard.
- `DEPLOYING.md` present at repo root.
- No `.claude/` directory at all.
- `docs/residual-review-findings/` present; no `docs/solutions/`, no `CONCEPTS.md`.

### leva
- `CLAUDE.md` only (30 lines) — a Rails **engine** (gem), not a full app: "Rails Engine Development Guide." Commands section, "Before Committing" checklist (rubocop → rubocop -a → rails test), code style (Ruby 3.2/Rails 7.2, YARD docs, annotaterb, Minitest `test_{description}` naming), points to `app/views/leva/design_system/` for UI changes.
- `.claude/commands/release-gem.md` — a custom slash command automating the full RubyGems release flow (version bump, CHANGELOG, git tag, `rake release`, OTP fallback instructions).
- No Kamal (`config/deploy.yml` absent — it's a gem, not a deployed service), no `docs/solutions/`, no `CONCEPTS.md`.

### every
- `CLAUDE.md` only (368 lines), classic "This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository" generated-template opening — **not** part of the AGENTS.md/symlink lineage.
- Comprehensive but generic-shaped: tech stack, dev commands, extensive testing section (Minitest, E2E Playwright with env-var table), Docker rake-task reference (`docker:up`/`docker:down`/`docker:rails`/`docker:test`), architecture/patterns, "Current Development Context," monitoring stack list (Sentry, Logtail, Ahoy, PostHog, PgHero, Searchjoy, Blazer).
- No Inertia (Webpack + Stimulus.js), no Kamal (Docker Compose + Heroku references), no `docs/solutions/`, no `CONCEPTS.md`, no `.claude/` directory. Oldest/most legacy-shaped stack of the survey.

### erf-rails
- `CLAUDE.md` only (154 lines), same generated-template opening line as `every`. Built on **Jumpstart Pro Rails** (a commercial multi-tenant SaaS starter) — Hotwire/Turbo/Stimulus + Hotwire Native, Devise + Pundit, Pay gem multi-processor billing, not Inertia.
- Documents the Jumpstart-specific patterns: modular `include Accounts, Agreements, ...` model organization, `config/jumpstart.yml` feature toggles, `Gemfile.jumpstart`.
- "Server Infrastructure" section: runs as a **launchd service** (not Kamal in practice) on port 3200, exposed via Tailscale HTTPS, with explicit unload/reload restart commands — despite `config/deploy.yml` being present, it is an **unedited Kamal template** (`service: my-app`, `image: your-user/my-app`), same as cora.
- No `.claude/` directory, no `docs/solutions/`, no `CONCEPTS.md`.

### blazer-ai
- `CLAUDE.md` only, shortest in the survey (22 lines), pure generated-template boilerplate: build/test commands + generic Ruby/Rails code-style bullets, nothing project-specific documented.
- No `docs/` directory at all, no `.claude/` directory, no Kamal config.

## 3. Recommendation for compound-stack-rails

1. **Ship `AGENTS.md` as the source of truth, `CLAUDE.md -> AGENTS.md` as a symlink.** This is the clean, repeated pattern in the most actively-maintained apps (thinkroom, riffrec-dashboard) and the `@AGENTS.md`-import variant in tada. It keeps one canonical file instead of two drifting copies (cora is the counter-example: two separate files with overlapping-but-different content, clearly harder to keep in sync). kieranklaassen-com shows AGENTS.md-only-no-CLAUDE.md is also viable but the symlink costs nothing and covers both agent tools.

2. **Seed a `docs/solutions/` directory with the house YAML-frontmatter convention** (`module`, `tags`, `problem_type`, and per riffrec-dashboard's fuller shape also `title`, `date`, `component`, `applies_when`), organized into category subdirectories. Present in cora, atelier, thinkroom, riffrec-dashboard — the strongest recurring convention in the survey tied to "documenting for AI agents." Reference it from AGENTS.md exactly as those four do: "relevant when implementing or debugging in a documented area."

3. **Seed an empty or lightly-seeded `CONCEPTS.md` at the repo root** with the framing line atelier/cora use almost verbatim: "Shared domain vocabulary — entities, named processes, and status concepts with project-specific meaning... accretes as ce-compound/ce-compound-refresh process learnings; direct edits are fine." Mention it conditionally in AGENTS.md ("`CONCEPTS.md`, when present" — thinkroom's phrasing) since a fresh starter has no domain vocabulary yet.

4. **Template the Kamal `config/deploy.yml` on environment variables**, following thinkroom/riffrec-dashboard/kieranklaassen-com exactly: `service: <%= ENV.fetch("KAMAL_SERVICE") %>`, `image: <%= ENV.fetch("KAMAL_IMAGE") %>`, hosts from a comma-split `ENV.fetch("KAMAL_HOSTS")`. This is the only Kamal config shape observed working across three different real deployments to a shared multi-tenant host, vs. the static `kieranklaassen/<app>` image pattern (diskman, lifegarden) which only makes sense for single-owner personal-VPS deploys, and vs. the unedited default template (cora, erf-rails) which signals Kamal isn't actually the deploy path. Ship a companion `DEPLOYING.md` (present in kieranklaassen-com, riffrec-dashboard, thinkroom) with the "read this first," worktree-doesn't-inherit-secrets, and never-rollback-blindly warnings riffrec-dashboard documents.

5. **AGENTS.md sections to standardize on**, based on the union of thinkroom/riffrec-dashboard/kieranklaassen-com/tada: "Local development" (bin/dev, Vite `skipProxy` caveat if using Inertia+Vite), git workflow guardrail (never commit/push to main — present in cora and tada explicitly), "Deploying" (Kamal + pointer to DEPLOYING.md), "Documented knowledge" (pointer to `docs/solutions/` and `CONCEPTS.md`), and a short "Architecture" section stating Inertia SSR/props ownership rules (kieranklaassen-com's "Rails owns routes and props; React pages do not fetch a parallel JSON API" is a good one-liner worth adopting verbatim as a starter guardrail).

6. **Do not pre-populate `.claude/agents/`, `.claude/commands/`, or `.claude/hooks/`** for the starter — this is the least consistent part of the survey (fully built out only in cora; empty or absent in the other 11 projects). Only `.claude/skills/` with the vendored `inertia-rails-*` skill set (present in cora and atelier) is worth including by default, since Inertia is a named part of the compound-stack-rails combination. If a `settings.json` is included, keep it minimal — cora's Bash-permission allowlist plus a `block-main-push.rb`-style PreToolUse hook is a reasonable optional add-on (guards the "never push main" rule mechanically instead of only documenting it) but should be opt-in, not default, since 11 of 12 surveyed projects ship none.

7. **Note the split by stack age/type as a boundary condition**: every, erf-rails, and blazer-ai — the non-Inertia or generated-template projects — show what compound-stack-rails should *not* imitate: generic "This file provides guidance to Claude Code..." boilerplate with no domain-specific sections, no `docs/solutions/`, no `CONCEPTS.md`. lifegarden shows the failure mode of having no AGENTS.md/CLAUDE.md at all despite being a live Kamal-deployed Inertia app — worth flagging in the starter's own docs as the thing to avoid letting drift.
