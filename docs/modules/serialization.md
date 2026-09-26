# Module: serialization

The default is **hand-written prop hashes**. Controllers build the exact hash a
page needs and pass it to `render inertia:`. Typed serializers (Alba/Typelizer)
are a documented opt-in, parked for now.

## What this module is

- Controllers shape props explicitly, e.g.:

  ```ruby
  render inertia: "users/show", props: {
    user: user.slice(:id, :email_address, :created_at),
  }
  ```

- **Never `as_json` on a model** — it leaks whatever columns exist (including
  `password_digest`). Always `slice`/pick the exact fields, or build the hash by
  hand.

## Why hand-written is the default

Only 1 of 8 surveyed Inertia apps used a typed serializer; the rest hand-write
props and `slice`. Hand-written hashes keep the prop contract visible in the
controller next to the page it feeds, with no serializer indirection to trace.

## Files (the module boundary)

This module is a **convention**, not files: it is the `render inertia:` prop
style used across controllers. Its boundary is "controllers build prop hashes
explicitly and never call `as_json` on a model."

## Adopt into an existing app

Audit controllers for `as_json`/`to_json` on models feeding Inertia and replace
them with explicit `slice`/hand-built hashes.

## Verify adoption

- `grep -rn "as_json" app/controllers` returns nothing that feeds an Inertia page.

## Opt-in: typed serializers (Alba + Typelizer)

When a fleet app grows enough shared serialization to want types, add `alba` +
`typelizer` to generate TypeScript types from Ruby resources. Documented as a
future add-on; not shipped by default.
