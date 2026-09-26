# Module: agent-conventions

One canonical, tool-agnostic agent-facing doc, plus the house documentation
conventions, seeded.

## What this module is

- **`AGENTS.md`** is the real file with the standardized sections: Architecture
  one-liner, Local development (incl. the Vite `localhost` / `skipProxy` caveat),
  the git-workflow guardrail (never commit/push to `main`), Users & auth,
  Deploying (pointer to `DEPLOYING.md`), Documented knowledge, and Template
  upgrades.
- **`CLAUDE.md` is a symlink to `AGENTS.md`** — one source of truth, readable by
  any tool that looks for either name.
- **`CONCEPTS.md`** seeds the shared vocabulary.
- **`docs/solutions/`** carries the YAML-frontmatter convention (see its README)
  and one seed example.
- **`.claude/agents|commands|hooks` are intentionally NOT pre-populated** — the
  survey showed these are the least-consistent, most app-specific part of the
  fleet. Each app adds its own; the template ships none.

## Files (the module boundary)

- `AGENTS.md`, `CLAUDE.md` (symlink)
- `CONCEPTS.md`
- `docs/solutions/README.md` + seed solution(s)

## Adopt into an existing app

1. Copy `AGENTS.md`; make `CLAUDE.md` a symlink to it (`ln -s AGENTS.md CLAUDE.md`).
2. Seed `CONCEPTS.md` and `docs/solutions/README.md`.
3. Do not import `.claude/` agents/commands/hooks from the template — keep those
   app-specific.

## Verify adoption

- `readlink CLAUDE.md` resolves to `AGENTS.md`.
- `AGENTS.md` carries the git-guardrail and Deploying sections.
- `docs/solutions/README.md` documents the frontmatter convention.
