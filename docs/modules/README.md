# Modules registry

Each file here documents one **independently adoptable module** of the template.
The set of module docs (excluding this README) is kept in 1:1 correspondence with
the `modules:` keys in `.template-manifest.yml` — enforced by
`test/template/manifest_test.rb`. A module can never be documented-but-unregistered
or registered-but-undocumented.

## The modules

| Module | What it is | Implementation unit |
|--------|-----------|---------------------|
| [frontend](frontend.md) | Inertia + Vite + React + TS + Tailwind, SSR wired-off | U2, U3 |
| [auth](auth.md) | Session auth, hardened, no open registration | U4 |
| [jobs](jobs.md) | Solid Queue in Puma + hourly prune | U5 |
| [testing](testing.md) | Minitest + fixtures + Vitest | U6 |
| [ci](ci.md) | SHA-pinned GitHub Actions skeleton | U7 |
| [deploy](deploy.md) | Env-driven Kamal, no committed secrets | U8 |
| [ruby_llm](ruby_llm.md) | ruby_llm first-class, test-safe | U9 |
| [serialization](serialization.md) | Hand-written prop hashes (Alba parked) | U9 |
| [riffrec](riffrec.md) | Feedback capture, no-op & secret-free | U10 |
| [agent-conventions](agent-conventions.md) | AGENTS.md + docs conventions | U11 |
| [ruby_native](ruby_native.md) | Native iOS/Android via rubynative.com, doc-first | — |
| [copse](copse.md) | Per-app/worktree dev hostnames, ports, DBs | — |
| [geneva_drive](geneva_drive.md) | Durable, resumable Active Job workflows | — |
| [pwa](pwa.md) | Installable PWA: manifest, Inertia-safe service worker, offline page | — |
| [feature_flags](feature_flags.md) | Flipper feature flags: per-user actors, YAML registry, admin UI, doc-first | — |
| [webmcp](webmcp.md) | One tool registry for MCP clients and WebMCP browser agents, session + CSRF | — |

## Module-doc template

Every `docs/modules/<name>.md` states, in order:

1. **Title + one-line purpose** — `# Module: <name>`.
2. **What this module is** — the capability, at altitude.
3. **Files (the module boundary)** — the exact files/paths that constitute the
   module. This is the boundary an upgrade agent reads.
4. **Adopt into an existing app** — the steps to bring the module into an app that
   does not have it yet (satisfies R8).
5. **Verify adoption** — the command(s) that prove the module is correctly in place.
6. *(optional)* **Decisions / opt-ins / gotchas** specific to the module.

Keep the boundary (section 3) accurate — it is what makes à la carte adoption and
agent-executed upgrades possible.
