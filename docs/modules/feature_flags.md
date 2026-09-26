# Module: feature_flags

Feature flags with [Flipper](https://www.flippercloud.io/docs), the way Cora
runs them: the signed-in **`User` is the actor**, every flag is registered in
one version-controlled YAML, production creates new flags **disabled**, and a
flag is flipped at runtime from the console or an admin-only dashboard. Turning
a feature on, off, or on for 10% of users never needs a deploy.

## What this module is

Flipper is a **staged-rollout tool for big new features**, not a config system.
Everything else ships unflagged: a flag doubles the paths under test, and a fix
parked behind a disabled flag is not fixed until someone enables it. Add one
only for a substantial new capability with a wide blast radius that you want
to roll out by cohort or percentage, or kill without a deploy. Never flag a bug
fix, copy, a refactor, or work already inside a flagged surface (a second dial
inside a flagged surface is a dial nobody turns).

The template ships this module **documentation-first**: most apps start with
zero flags, so the gems are not bundled. Adoption is the mechanical set of
steps below, lifted from Cora.

- **Gems:** `flipper`, `flipper-active_record` (gates live in two tables in the
  app's own database, SQLite or Postgres alike), `flipper-ui` (the dashboard).
- **Actor:** the `User`. Flipper's engine mixes `Flipper::Model::ActiveRecord`
  into every model, so `user.flipper_id` is `"User;<id>"` with no code. Flags
  on account-scoped surfaces still target the owning user, never the account.
- **Groups:** `:admins` and `:beta_testers`, registered from `User#admin?` and
  `User#beta_tester?`, so a flag can go to the team first.
- **Registry:** `config/flipper_flag_defaults.yml`, one entry per flag with
  `enabled` (a dev/CI seed only), `purpose`, and `usage`. Loaded once at boot;
  in production every unknown flag is created **disabled** whatever the YAML
  says, so features are opt-in by construction.
- **Client:** the layout embeds each flag's value for the current user as a
  non-executable JSON `<script>`; a small TS reader and `useFlipperFlag()` read
  it. Flags are not Inertia props: one query per full page load, none per visit.
- **Dashboard:** `Flipper::UI` at `/admin/flipper` behind an admin-only route
  constraint; non-admins get a 404, not a sign-in redirect.

## Files (the module boundary)

- `docs/modules/feature_flags.md`, this doc (the module is doc-first in the template).
- After adoption in an app: the three gems in the `Gemfile`,
  `config/initializers/flipper.rb`, `config/flipper_flag_defaults.yml`,
  `db/migrate/*_create_flipper_tables.rb`, `config.flipper.preload = false` in
  `config/application.rb`, `app/helpers/flipper_flags_helper.rb`, the layout's
  `flipper_flags_script_tag` call, the `/admin/flipper` mount,
  `app/frontend/lib/flipper_flags.ts`, `app/frontend/test/flipper_flags.ts`.

Depends on **auth** (`Current.user` is the actor; the dashboard constraint
reads the session cookie) and **frontend** (layout and Vite entrypoint).

## Adopt into an existing app

1. Add the gems, then let Flipper generate its initializer stub and migration:

   ```ruby
   # Feature flags: per-user staged rollout without a deploy (docs/modules/feature_flags.md)
   gem "flipper", "~> 1.3"
   gem "flipper-active_record", "~> 1.3"
   gem "flipper-ui", "~> 1.3"
   ```

   ```sh
   bundle install && bin/rails g flipper:setup && bin/rails db:migrate
   ```

2. Replace the generated `config/initializers/flipper.rb` with the groups and
   the registry loader:

   ```ruby
   Flipper.register(:admins) { |actor| actor.respond_to?(:admin?) && actor.admin? }
   Flipper.register(:beta_testers) { |actor| actor.respond_to?(:beta_tester?) && actor.beta_tester? }

   module Flipper
     # Hydrates a checkout from the YAML registry. Runs once at boot, skips when the
     # table is not there yet (fresh clone, CI before db:prepare), and in production
     # creates every new flag DISABLED whatever the YAML says.
     def self.load_flag_defaults!
       return unless ActiveRecord::Base.connection_pool.with_connection { |c| c.data_source_exists?("flipper_features") }

       (YAML.safe_load_file(Rails.root.join("config/flipper_flag_defaults.yml")) || {}).each do |name, config|
         next if Flipper.exist?(name)

         Flipper.add(name)
         Flipper.enable(name) if config["enabled"] && !Rails.env.production?
       end
     rescue ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished
       nil
     end
   end

   Rails.application.config.after_initialize { Flipper.load_flag_defaults! }
   ```

3. In `config/application.rb`, add `config.flipper.preload = false`. Flipper's
   memoizer middleware otherwise runs a `flipper_features LEFT JOIN
   flipper_gates` on every request; Cora turned it off when that join reached
   2s on hot paths at 100+ flags. Memoization stays on, so repeat checks of one
   flag inside a request are free.

4. Create `config/flipper_flag_defaults.yml`. Every flag in code has an entry;
   it is the registry and the documentation in one place:

   ```yaml
   focus_mode:
     enabled: false   # dev/CI seed only; production always starts disabled
     purpose: "One-email-at-a-time inbox sweep"
     usage: |
       Gates FocusController (404 when off) and the Focus sidebar row via
       useFlipperFlag("focus_mode"). Actor: the User.
   ```

5. Mount the dashboard behind an admin-only constraint in `config/routes.rb`.
   The template's auth has no admin notion, so add `admin:boolean` (default
   `false`) to `users` and set it from the console; there is no self-serve path.

   ```ruby
   admin_only = ->(request) { Session.find_by(id: request.cookie_jar.signed[:session_id])&.user&.admin? }
   constraints(admin_only) { mount Flipper::UI.app(Flipper) => "/admin/flipper" }
   ```

6. Expose flags to the client: a helper renders one JSON script tag just before
   `</body>` in the layout, and a reader parses it once.

   ```ruby
   # app/helpers/flipper_flags_helper.rb
   module FlipperFlagsHelper
     # Non-executable JSON; ActiveSupport::JSON escapes <, >, and & so it can never contain </script>.
     def flipper_flags_script_tag
       flags = Flipper.preload_all.to_h { |feature| [feature.name.to_s, feature.enabled?(Current.user)] }
       tag.script(ActiveSupport::JSON.encode(flags).html_safe, type: "application/json", id: "flipper-flags")
     end
   end
   ```

   ```ts
   // app/frontend/lib/flipper_flags.ts
   // Keep the union in step with the YAML. Cora generates it from the YAML at boot
   // (FlipperFlags::TypeGenerator) so a stale name fails tsc; hand-maintain it until then.
   export type FlipperFlagName = "focus_mode"
   type Flags = Partial<Record<FlipperFlagName, boolean>>

   let cache: Flags | null = null

   function read(): Flags {
     if (cache) return cache
     const el = typeof document === "undefined" ? null : document.getElementById("flipper-flags")
     try { cache = el?.textContent ? (JSON.parse(el.textContent) as Flags) : {} } catch { cache = {} }
     return cache
   }

   export const resetFlipperFlagsCache = (): void => { cache = null }
   export const useFlipperFlag = (name: FlipperFlagName): boolean => read()[name] === true
   ```

7. Copy `app/frontend/test/flipper_flags.ts` (see Testing) and this doc into the
   app; run the verification below; add `feature_flags: "<template_version>"`
   to `.template-manifest.yml`.

## Conventions

- **Check with the actor, always:** `Flipper.enabled?(:focus_mode, Current.user)`.
  A bare `Flipper.enabled?(:focus_mode)` sees only the boolean gate and silently
  misses actor, group, and percentage rollouts. The one exception is an
  infrastructure kill switch (`auto_scale_workers`), boolean-only by design.
  Unknown flags return `false` and never raise; development warns (Flipper's
  strict mode), which is the nudge to add the YAML entry.
- **Controllers gate with a `before_action` that 404s**, so the surface does not
  exist for users outside the rollout. ERB makes the same call; React reads
  `useFlipperFlag("focus_mode")`. Server-decided behaviour a page depends on
  (page size, which loader ran) travels as an ordinary Inertia prop; the script
  tag is for pure UI gating.

  ```ruby
  class FocusController < InertiaController
    before_action { head :not_found unless Flipper.enabled?(:focus_mode, Current.user) }
  end
  ```

- **Shadow mode for anything that acts on data.** Always run the new logic, act
  only when the flag is on, and log what would have happened otherwise, so a
  disabled deploy already tells you whether the rollout is safe:

  ```ruby
  if Flipper.enabled?(:phishing_detection, email.user)
    classify_as_spam(email)
  else
    Rails.logger.info "[PHISHING] Shadow mode: #{email.id} would be classified as spam"
  end
  ```

- **Naming:** lowercase snake_case identifiers (they become TS property names)
  that describe the capability, not the change: `focus_mode`,
  `inbox_infinite_scroll`, `briefs_v2` for a rewrite of an existing surface.
  Never a ticket number or a date.
- **Rollout ladder,** from the console or the dashboard; every rung is
  reversible and none needs a deploy. A cohort step that must reach every
  environment ships as a data migration (`Flipper.enable_group(:focus_mode, :admins)`
  in `up`, `disable_group` in `down`). Put the rollout plan in the PR.

  ```ruby
  Flipper.enable(:focus_mode, User.find_by!(email_address: "you@example.com"))  # yourself
  Flipper.enable_group(:focus_mode, :admins)                                    # the team
  Flipper.enable_percentage_of_actors(:focus_mode, 10)                          # 10%, sticky per user
  Flipper.enable(:focus_mode)                                                   # everyone
  Flipper.disable(:focus_mode)                                                  # emergency rollback
  ```

- **Clean up at 100%.** A fully enabled flag is debt. Delete every
  `Flipper.enabled?` and `useFlipperFlag` call and the dead branch, delete the
  YAML entry and the name from `FlipperFlagName`, then ship a migration that
  deletes the rows. Direct SQL keeps it independent of the Flipper
  configuration and a no-op on a fresh database; `down` re-inserts the
  `flipper_features` row (disabled) so the migration stays reversible.

  ```ruby
  class RemoveFocusModeFlag < ActiveRecord::Migration[8.1]
    def up
      return unless table_exists?(:flipper_features)

      execute "DELETE FROM flipper_gates WHERE feature_key = #{connection.quote("focus_mode")}"
      execute "DELETE FROM flipper_features WHERE key = #{connection.quote("focus_mode")}"
    end
  end
  ```

## Testing

- **Ruby.** In the test environment Flipper swaps in a shared **Memory adapter**
  and removes every feature before each test (`config.flipper.test_help`, on by
  default), so the flag-off path is the default and a test enables what it needs
  on the fixture user. Cora still disables in `teardown`; the reset makes that
  optional. Cover both branches of every gate:

  ```ruby
  test "focus is 404 until the flag is on for the user" do
    sign_in_as users(:one)
    get focus_path
    assert_response :not_found

    Flipper.enable(:focus_mode, users(:one))
    get focus_path
    assert_response :success
  end
  ```

- **Vitest.** A helper installs the JSON script tag the reader parses; call
  `clearFlipperFlags()` in `afterEach` so flags never leak between tests:

  ```ts
  // app/frontend/test/flipper_flags.ts
  import { resetFlipperFlagsCache } from "~/lib/flipper_flags"

  export function clearFlipperFlags(): void {
    document.getElementById("flipper-flags")?.remove()
    resetFlipperFlagsCache()
  }

  export function setFlipperFlags(flags: Record<string, boolean>): void {
    clearFlipperFlags()
    const el = Object.assign(document.createElement("script"), { type: "application/json", id: "flipper-flags" })
    el.textContent = JSON.stringify(flags)
    document.body.appendChild(el)
  }
  ```

- **Lock the config.** One test asserts `Rails.application.config.flipper.preload`
  is `false` and `Flipper::Middleware::Memoizer` is in the middleware stack, so
  an `application.rb` edit cannot quietly bring the per-request join back.

## Verify adoption

- `bundle list | grep flipper` shows the three gems; `bin/rails db:migrate:status`
  shows the flipper tables migration `up`.
- `bin/rails runner 'puts Flipper.features.map(&:name)'` lists every flag in
  `config/flipper_flag_defaults.yml`; in production each one reads disabled.
- `bin/rails test` and `npm run check` are green, including a flag-off and a
  flag-on test for each gate.
- Signed out or as a non-admin, `GET /admin/flipper` is 404; as an admin it
  renders the dashboard.

## Decisions & gotchas

- **Notify on change.** Cora subscribes to `feature_operation.flipper` and posts
  every `enable`, `disable`, `add`, and `remove` (with gate and value) to Slack
  from a job. Add it once more than one person flips flags.
- **The YAML seeds, it does not sync.** `enabled:` applies only when a flag is
  first created outside production. Changing it later does nothing to an
  existing flag; flip the flag itself.
- **Percentage gates are per actor, not per request.** `enable_percentage_of_actors`
  hashes `flipper_id`, so a user stays in or out of the cohort across requests.
  `enable_percentage_of_time` does not, and is only for load shedding.
