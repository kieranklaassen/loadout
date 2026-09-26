---
title: Inertia asset version 500s under load on a process-wide Dir.chdir
module: frontend
date: 2026-09-17
problem_type: bug
component: config/initializers/inertia_rails.rb
tags: [inertia, vite, threads, puma, chdir]
applies_when: A threaded server (Puma) serves Inertia responses whose asset version calls ViteRuby.digest.
---

## Problem

Intermittent 500s on Inertia requests under concurrency, with this in the logs:

```
RuntimeError: conflicting chdir during another chdir block
```

A fleet app reproduced it at 2 × 500 out of 40 concurrent `X-Inertia: true`
requests. It never showed up in development or in the test suite.

## Cause

`config.version = -> { ViteRuby.digest }` runs on every Inertia response.
`ViteRuby.digest` delegates to `ViteRuby::Builder#watched_files_digest`, which
wraps its work in `ViteRuby::Config#within_root` — and that is just:

```ruby
def within_root(&block)
  Dir.chdir(File.expand_path(root), &block)
end
```

**Block-form `Dir.chdir` is process-wide.** Ruby allows only one active chdir
block per process, tracked against the thread that opened it. A second thread
entering while the first is inside raises, regardless of whether both target the
same directory. Under Puma that second thread is another user's request.

Two things kept this hidden:

- **vite_ruby's 1-second memo.** `watched_files_digest` returns early for a second
  after each computation, so most calls never reach `chdir` at all. The window
  reopens on every expiry and is always open on a cold process.
- **It needs a GVL yield mid-block.** Two threads merely *calling* the digest is
  not enough — one has to be suspended *inside* the chdir block when the other
  enters. The block is ~2-26 ms of globbing and SHA1, so under real load this
  happens often; in a quiet test it almost never does. That is why 32 threads
  hammering `ViteRuby.digest` in a test passes cleanly while production 500s.

There is a third, quieter defect: `@last_digest` and `@last_digest_at` are read
and written with no synchronization, so concurrent callers can observe a digest
from a half-finished computation.

## Solution

Guard the whole call with a mutex, and memoize where the digest cannot change:

```ruby
vite_digest_lock = Mutex.new
vite_digest = nil

config.version = lambda do
  vite_digest_lock.synchronize do
    next ViteRuby.digest if Rails.env.local?

    vite_digest ||= ViteRuby.digest
  end
end
```

The lock has to wrap the **entire** call, not just the chdir — the early-return
memo check reads shared state too, so a narrower lock would leave that race open.

**Why memoize outside `local?`:** under Kamal a rebuilt frontend ships a new
container, so the watched files cannot change for the life of the process.
Memoizing removes a directory glob plus a SHA1 of every watched file from every
Inertia response, and leaves the mutex uncontended after the first request instead
of making it a process-wide serialization point on a hot path. Development and
test keep recomputing so a rebuilt frontend still invalidates client history
without a restart.

**Why `Rails.env.local?` and not `production?`:** memoizing in `test` would make
the regression test vacuous. After the first call the memo would short-circuit
every later call before it reached `Dir.chdir`, so the test would pass with the
mutex removed and prove nothing. `local?` is exactly `development || test`.

## Prevention

**Treat any gem call that enters `Dir.chdir` as unsafe on a threaded request
path.** It is process-global state wearing a block-scoped API, and the failure is
load-dependent, so it survives code review and testing and surfaces in production.
When you find one, either serialize it or hoist it out of the request path.

**Making an intermittent race deterministic in a test.** Asserting "N threads, no
exception" is not a regression test for this class of bug — it passes without the
fix. Force the interleaving instead: park one thread *inside* the real chdir block
and signal once it is there, then release a second thread.

```ruby
config.define_singleton_method(:within_root) do |&block|
  original.call do
    if first_caller?
      signal << :inside   # second thread starts only after this
      sleep 0.2
    end
    block.call
  end
end
```

Only the dwell time is manufactured — the `RuntimeError` still comes from Ruby's
own chdir bookkeeping. This goes red every run without the fix, instead of one run
in twenty. See `test/initializers/inertia_version_thread_safety_test.rb`.

Always confirm such a test is load-bearing by removing the fix and watching it
fail. A concurrency test never observed failing is not a regression test.

**Upstream escape hatch.** `Dir.glob` accepts a `base:` keyword, so `within_root`
would not need `chdir` at all. If that lands in vite_ruby, this guard can be
reconsidered — until then the template owns the fix, because it owns the
initializer.
