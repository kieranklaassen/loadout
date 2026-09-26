# docs/changelog — agent-executable upgrade entries

Entries here are **imperative upgrade instructions an agent executes against a
downstream app** — not human release notes. Each entry describes what to change
in an app that adopted the affected module(s), so an upgrade agent can apply it
unattended and open a reviewable PR.

## Entry file convention

One file per entry, named:

```
docs/changelog/<template_version>-<NNN>-<slug>.md
```

e.g. `0.1.0-001-initial-template.md`. `<NNN>` is a zero-padded sequence within a
version. Each entry has YAML frontmatter and an imperative body:

```markdown
---
template_version: "0.2.0"      # the version this change ships in (semver)
modules: [deploy]              # affected module(s); non-empty list of manifest keys
type: feat                     # feat | fix | refactor
---

## Instructions

1. In `config/deploy.yml`, add `...`.
2. Run `...`.
3. Verify `bin/rails test test/deploy_config_test.rb` passes.
```

Bodies are written in the imperative ("add", "replace", "run", "verify") and are
self-contained: an agent should be able to apply the change and confirm it
without reading the template's own diff.

## The filter + apply algorithm (what an upgrade agent runs)

Given a downstream app's `.template-manifest.yml`:

1. **Select** every entry whose `template_version` is **greater than** the app's
   `template_version` AND whose `modules` **intersect** the app's adopted
   `modules`.
2. **Order** the selected entries ascending by `template_version` then `NNN`.
3. **Apply** each entry's instructions in order.
4. **Bump** the app's `template_version` to the newest applied entry's version.
5. **Open a reviewable PR** on the downstream app — **never a direct push** (R6).

Entries whose modules the app has not adopted are skipped. An entry that names a
module absent from the app's manifest contributes nothing for that app.

## Referential integrity

Every `modules` entry must be a real module — a key that exists in
`.template-manifest.yml`. Enforced by `test/template/changelog_test.rb`.

## Index

The human-readable index of entries is [`CHANGELOG.md`](../../CHANGELOG.md).
