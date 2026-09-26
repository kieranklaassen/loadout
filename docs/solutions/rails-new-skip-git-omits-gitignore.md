---
title: rails new --skip-git omits .gitignore and .gitattributes
module: none
date: 2026-08-12
problem_type: gotcha
component: .gitignore
tags: [rails, git, bootstrap]
applies_when: Bootstrapping into an existing git repo with `rails new . --skip-git`.
---

## Problem

After `rails new . --skip-git`, a plain `git add -A` staged ~1500 files that
should never be tracked — `tmp/cache/**`, `log/*.log`, `storage/*.sqlite3`, and
worst of all `config/master.key`.

## Cause

Rails gates the creation of `.gitignore` and `.gitattributes` on `!skip_git`. So
`--skip-git` (correct when the repo already exists) also skips generating the
ignore file, leaving nothing to exclude generated and secret files.

## Solution

Write `.gitignore` and `.gitattributes` by hand immediately after `rails new
--skip-git` (Rails' standard contents plus `/node_modules`, `/public/vite*`, and
`/config/master.key`). Then untrack anything already added:

```sh
git rm -r --cached tmp/cache log storage/*.sqlite3 config/master.key
```

## Prevention

Never `git add -A` right after `rails new --skip-git` without first confirming a
`.gitignore` exists and `git status` shows only intended files.
