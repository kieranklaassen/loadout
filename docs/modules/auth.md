# Module: auth

Database-backed session authentication built on the Rails 8 `authentication`
generator, hardened to the house standard. No open registration: users are
created only by `bin/rails users:create`.

## What this module is

- `has_secure_password` + a DB-backed `Session` model; the signed, permanent
  `session_id` cookie (`httponly`, `same_site: :lax`) is the only credential a
  browser carries.
- The gate lives on `InertiaController` (default-on), so **every Inertia page is
  authenticated unless it opts out** with `allow_unauthenticated_access`.
  Framework endpoints (e.g. `/up`) inherit from `ApplicationController` and stay
  public.
- Operational hardening: a 72-byte password guard (bcrypt truncates silently past
  that), a 12-byte minimum, a byte-identical `"Invalid email or password."` for
  both unknown-email and wrong-password (no enumeration oracle), and sign-in
  rate limiting against an **explicitly-owned** `MemoryStore` (not `Rails.cache`,
  which can be a silent null store under class-body eval timing).

## Files (the module boundary)

- `app/models/user.rb` — `has_secure_password`, email normalization, password guards.
- `app/models/session.rb`, `app/models/current.rb`
- `app/controllers/concerns/authentication.rb` — the gate + session lifecycle.
- `app/controllers/inertia_controller.rb` — `include Authentication` (gate default-on).
- `app/controllers/sessions_controller.rb` — sign in/out, generic failure, rate limit.
- `app/frontend/pages/auth/sign_in.tsx` — the sign-in page.
- `app/channels/application_cable/connection.rb` — cable identity from the session cookie.
- `config/routes.rb` — `resource :session`.
- `db/migrate/*_create_users.rb`, `db/migrate/*_create_sessions.rb`
- `lib/tasks/users.rake` — `users:create` (the sole user writer).
- `test/fixtures/users.yml`, `test/models/user_test.rb`,
  `test/controllers/sessions_controller_test.rb`, `test/tasks/users_rake_test.rb`,
  `test/test_helpers/session_test_helper.rb`

## Adopt into an existing app

1. Run `bin/rails generate authentication`, then apply the house adaptations:
   move `include Authentication` from `ApplicationController` to the base
   `InertiaController`; make public actions call `allow_unauthenticated_access`.
2. Copy `app/models/user.rb`'s password guards (`MAXIMUM_PASSWORD_BYTES = 72`,
   `MINIMUM_PASSWORD_LENGTH`).
3. Replace the generated ERB session view with `app/frontend/pages/auth/sign_in.tsx`
   and set `SessionsController#new` to `render inertia: "auth/sign_in"`.
4. Harden `SessionsController#create`: generic failure message + an owned
   `RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new` passed to
   `rate_limit(..., store:)`.
5. Delete any registration route; add `lib/tasks/users.rake`.
6. `bin/rails db:migrate`.

## Verify adoption

- `bin/rails test test/models/user_test.rb test/controllers/sessions_controller_test.rb test/tasks/users_rake_test.rb`
- `EMAIL=you@example.com PASSWORD='a-long-password' bin/rails users:create` creates a user.
- An unauthenticated request to a gated Inertia page redirects to sign-in.

## Decisions & opt-ins

- **Password reset is not shipped.** The generator's `PasswordsController`/mailer
  reset flow was trimmed — it needs mail delivery configured and Inertia pages.
  Re-add it as an opt-in when an app configures a mailer.
- **OmniAuth is an opt-in account-linking path, not primary login.** Add the
  provider gems and link providers to an existing `User`; do not open
  self-registration.
- **No open registration** is a deliberate default. `users:create` is the sole
  writer; adding a registration flow is an explicit product decision.
