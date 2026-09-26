# docs/solutions

Durable, dated write-ups of problems we solved, so the next person (or agent)
does not rediscover them. One file per solution, kebab-case filename, with YAML
frontmatter.

## Frontmatter convention

```yaml
---
title: Short description of the problem
module: auth            # the docs/modules/<name> this relates to, or "none"
date: 2026-08-12        # absolute date the solution was captured
problem_type: gotcha    # gotcha | bug | performance | config | design
component: config/…      # the file/area involved
tags: [rails, kamal]    # freeform search tags
applies_when: One line describing the situation in which this solution applies.
---
```

Then the body: **Problem**, **Cause**, **Solution**, and (optionally)
**Prevention**. Keep it tight — a screen or two.

## Why this exists

Solutions here are the raw material for `docs/changelog/` entries: when a fix is
worth propagating to the fleet, it becomes an agent-executable changelog entry.
See `AGENTS.md` → Documented knowledge.
