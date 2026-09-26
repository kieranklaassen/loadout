# Module: jobs

Solid Queue is the Active Job backend, running **inside Puma** by default (no
separate worker process to operate) with a mandatory hourly prune.

## What this module is

- `config.active_job.queue_adapter = :solid_queue`, with the queue on its own
  SQLite database (`config.solid_queue.connects_to = { database: { writing: :queue } }`).
- In-Puma execution: `config/puma.rb` runs `plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]`.
  Production sets `SOLID_QUEUE_IN_PUMA=true` (see the deploy module). Scale out to
  a dedicated `job` role later by setting `JOB_CONCURRENCY` and running `bin/jobs`.
- A single worker pool (`queues: "*"`, `threads: 3`, `processes` from
  `JOB_CONCURRENCY` defaulting to 1, `polling_interval: 0.1`) and a dispatcher
  (`polling_interval: 1`, `batch_size: 500`).
- A mandatory hourly recurring prune
  (`SolidQueue::Job.clear_finished_in_batches`) so `solid_queue_jobs` never grows
  unbounded.

## Files (the module boundary)

- `config/queue.yml` — worker/dispatcher pools.
- `config/recurring.yml` — the hourly prune, keyed per environment.
- `config/puma.rb` — the `plugin :solid_queue` line.
- `config/environments/production.rb` — the adapter + `connects_to` lines.
- `app/jobs/application_job.rb`
- `test/jobs/recurring_schedule_test.rb`

## Adopt into an existing app

1. Ensure `solid_queue` is installed (`bin/rails solid_queue:install`) and the
   `queue` database is declared in `config/database.yml`.
2. Copy `config/queue.yml` and `config/recurring.yml` (keep the per-environment
   keys — see the gotcha below).
3. Add `plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"]` to `config/puma.rb`
   and set `SOLID_QUEUE_IN_PUMA=true` in production.
4. Delete any `config/schedule.rb` / `whenever` gem — `recurring.yml` replaces it.

## Verify adoption

- `bin/rails test test/jobs/recurring_schedule_test.rb`
- `bin/rails runner 'SolidQueue::Job.clear_finished_in_batches'` runs without error.

## Gotcha: config_from silently loads nothing

Solid Queue reads `recurring.yml` keyed by the current environment. If the
current environment has **no top-level key**, it loads *nothing* — no error, no
recurring jobs. That is why every environment has an explicit key (via a YAML
anchor). Enabling the scheduler in a new environment therefore never silently
does nothing.
