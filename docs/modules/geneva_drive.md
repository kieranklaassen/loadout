# Module: geneva_drive

[Geneva Drive](https://github.com/julik/geneva_drive) provides durable,
resumable, multi-step Rails workflows backed by Active Record and Active Job.
This stack ships the open-source 0.6.0 engine without routes or an admin UI.

## What this module is

- `geneva_drive` 0.6.0 from RubyGems, constrained to the 0.6 patch line.
- Two primary-database tables that persist workflow state and every step
  attempt, including failure details.
- Step execution through the existing Active Job/Solid Queue `default` queue.
- `GenevaDrive::HousekeepingJob` every 30 minutes for retention cleanup and
  recovery of work whose queue job was lost or whose worker stopped.
- A backend building block. Applications define workflows around their own
  domain records; the module adds no controller, route, Inertia prop, or UI.

The `jobs` module is a prerequisite. Before adopting Geneva Drive, confirm that
Solid Queue is the Active Job adapter, its queue database is separate from the
primary database, a worker consumes `default` (or `*`), and
`config/recurring.yml` is active in the target environment.

## Files (the module boundary)

- `Gemfile` and `Gemfile.lock` — `gem "geneva_drive", "~> 0.6.0"`, locked at
  the reviewed 0.6.0 release.
- `config/initializers/geneva_drive.rb` — released retention, recovery, batch,
  and test enqueue defaults.
- `db/migrate/*geneva_drive*.rb` — all nine migrations emitted by the 0.6.0
  installer (0.6.0 added workflow `metadata`, the in-progress `started_at`
  recovery index, and the resumable-step `cursor` / `continues_from_id` columns), with the nullable-hero migration temporarily removing and restoring
  SQLite's inbound foreign key so the parent-table swap preserves step history.
- `db/schema.rb` — `geneva_drive_workflows` and
  `geneva_drive_step_executions`, their indexes, and foreign key.
- `config/recurring.yml` — 30-minute housekeeping.
- `config/database.yml` and `config/environments/test.rb` — a separate test
  queue database used by the Solid Queue integration proof.
- `test/workflows/geneva_drive_smoke_test.rb` — workflow, queue, duplicate
  delivery, pause/resume, and lost-enqueue recovery coverage.
- `test/migrations/geneva_drive_migration_test.rb` — populated SQLite migration
  proof for retained step history and valid foreign keys.
- `test/jobs/recurring_schedule_test.rb` — recurring-task inheritance.

## Adopt into an existing app

Adoption is explicit for existing apps. The normal upgrade filter skips a new
module until the app records it, so first choose Geneva Drive, apply the
instructions below (or the 0.4.0 changelog entry), verify them, and only then add
`geneva_drive: "0.4.0"` to the app's `.template-manifest.yml`.

1. Adopt the `jobs` module first if the Solid Queue preflight above fails.
2. Add `gem "geneva_drive", "~> 0.6.0"` to `Gemfile` and run
   `bundle install`. Confirm `bundle info geneva_drive` reports 0.6.0.
3. Run `bin/rails generate geneva_drive:install`. Keep the generated
   initializer and all nine migrations. In the initializer comment, use the real
   setting name `stuck_in_progress_threshold` if the generator still writes the
   older `stuck_executing_threshold` name.
4. Review the migrations and back up populated databases. In
   `AllowNullHeroOnGenevaDriveWorkflows`, remove the inbound
   `geneva_drive_step_executions.workflow_id` foreign key before the generated
   SQLite parent-table swap and restore it afterward with `on_delete: :cascade`;
   otherwise the drop deletes existing step history. Run `bin/rails db:migrate`,
   then confirm both Geneva Drive tables and their partial unique indexes appear
   in `db/schema.rb`.
5. Merge this task into the shared recurring anchor for every environment:

   ```yaml
   geneva_drive_housekeeping:
     class: "GenevaDrive::HousekeepingJob"
     schedule: "*/30 * * * *"
   ```

6. Give test a separate queue database matching production while leaving Active
   Job on its test adapter by default:

   ```yaml
   test:
     primary:
       <<: *default
       database: storage/test.sqlite3
     queue:
       <<: *default
       database: storage/test_queue.sqlite3
       migrations_paths: db/queue_migrate
   ```

   Add this to `config/environments/test.rb`:

   ```ruby
   config.solid_queue.connects_to = { database: { writing: :queue } }
   ```

7. Copy the focused workflow, migration, and recurring-schedule tests, adapting
   the test hero to an existing application model. Copy this boundary doc into
   the app.
8. Run the verification below, then register `geneva_drive: "0.4.0"` in the
   manifest. Set `template_version` to at least `"0.4.0"`, but never lower a
   newer value. Future module-filtered upgrades will now include Geneva Drive.

## Define the first workflow

Workflows are ordinary Ruby classes. Keep the durable state in a domain model
(the `hero`) and make every non-transactional effect idempotent.

```ruby
class OnboardingWorkflow < GenevaDrive::Workflow
  step :mark_started do
    hero.update!(onboarding_started_at: Time.current)
  end

  step :send_welcome do
    WelcomeMailer.with(user: hero).welcome.deliver_later
  end
end

OnboardingWorkflow.create!(hero: user)
```

For payments, email providers, and other external systems, pass a stable domain
idempotency key (for example, the order ID plus operation name). Geneva Drive
deduplicates delivery of a completed persisted step, but a worker can stop after
an external effect succeeds and before completion is recorded. Housekeeping may
then reattempt that effect. Do not describe arbitrary external effects as
exactly once.

Keep workflow instances short-lived across deploys. Persisted executions refer
to step names in loaded Ruby code, so do not remove or rename a step while older
instances can still reach it.

## Operate the module

The released defaults are:

- delete finished and canceled workflows after 30 days;
- recover `in_progress` steps after one hour;
- recover overdue `scheduled` steps after 15 minutes;
- recover by reattempting, in batches of 1,000;
- enqueue immediately in tests and after the primary transaction commits in
  other environments.

With a separate primary and queue database, a primary commit and queue insert
are not atomic. Housekeeping recovers a lost immediate enqueue after the
15-minute stale threshold plus up to one 30-minute schedule interval. Do not use
`GenevaDrive.with_inline_enqueue` in this topology; upstream reserves it for
database-backed adapters that co-commit with the workflow records.

The open-source engine has no operator UI. Use `bin/rails console`:

```ruby
paused = GenevaDrive::Workflow.paused.order(:updated_at)
workflow = paused.find(id)
workflow.execution_history.last.attributes.slice(
  "step_name", "state", "error_class_name", "error_message", "error_backtrace"
)
workflow.resume! # retry after correcting the cause
workflow.cancel! # terminate and release the hero's uniqueness slot
```

Also inspect stale work with
`GenevaDrive::StepExecution.where(state: "scheduled").where("scheduled_for < ?", 15.minutes.ago)`
and the equivalent `in_progress` query on `started_at` and one hour.

Failure messages and full backtraces live in the primary database. Finished and
canceled rows age out after 30 days, but paused workflows retain those details
until they are resumed or canceled. Treat the tables and database backups as
sensitive diagnostic data. Never put secrets, tokens, or unnecessary personal
data in exception messages.

Geneva Drive 0.6.0 ships the partial `started_at` index that keeps the
in-progress recovery scan fast. Still monitor housekeeping duration against its
30-minute interval and workflow/step-execution row growth, and do not
cherry-pick unreleased migrations from upstream `main`.

## Upgrade Geneva Drive

Treat every version change, including a 0.6 patch release, as a schema-bearing
upgrade:

1. Read the upstream changelog and update only Geneva Drive in the bundle.
2. Run `bin/rails generate geneva_drive:install` again. The installer copies any
   migrations missing from the app.
3. Review every new migration. Back up populated SQLite data before a generated
   table rebuild. If the installer rewrites the v0.5.0 nullable-hero migration,
   reapply the local foreign-key removal/restoration around its SQLite swap
   before migrating; the generated drop-and-rename branch deletes child step
   history through its cascading foreign key.
4. Reapply the local initializer-comment correction if upstream still emits the
   old setting name, migrate, compare workflow and step-execution row counts,
   require `PRAGMA integrity_check` to return `ok`, require
   `PRAGMA foreign_key_check` to return no rows, and run the verification below.
5. Advance the module's manifest version only after the checks pass.

## License

The open-source gem is licensed under LGPLv3; the author separately offers a
commercial license. A proprietary downstream app must confirm which licensing
basis applies before distribution. This module records the choice but does not
make a legal conclusion for an adopter. See the upstream
[LGPLv3 text](https://github.com/julik/geneva_drive/blob/v0.6.0/LICENSE-LGPL.txt)
and [commercial terms](https://github.com/julik/geneva_drive/blob/v0.6.0/LICENSE-COMMERCIAL.txt).

## Verify adoption

- `bundle info geneva_drive` reports 0.6.0.
- `RAILS_ENV=test bin/rails db:prepare` builds the primary and queue databases.
- `bin/rails test test/workflows/geneva_drive_smoke_test.rb test/jobs/recurring_schedule_test.rb`
  passes.
- `bin/rails runner 'puts [GenevaDrive::Workflow.table_exists?, GenevaDrive::StepExecution.table_exists?].inspect'`
  prints `[true, true]`.
- `bin/rails test` and `bin/rubocop` remain green.
