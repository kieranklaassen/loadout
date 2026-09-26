# Pattern survey: Background jobs

Surveyed: cora, atelier, tada, diskman, lifegarden, thinkroom, riffrec-dashboard, kieranklaassen-com, leva, every, erf-rails, blazer-ai.

## Summary

The dominant pattern across recent, actively-developed apps (cora, tada, diskman, riffrec-dashboard, erf-rails — all built on the same Rails 8 + Kamal jumpstart-style base) is **Solid Queue** as the ActiveJob backend, configured with `config/queue.yml` (a single `workers:` pool draining `queues: "*"` or an explicit allowlist, `threads: 3`, `processes: ENV JOB_CONCURRENCY`, `polling_interval: 0.1`, dispatcher `polling_interval: 1` / `batch_size: 500`) plus `config/recurring.yml` for scheduled work (Solid Queue's built-in recurring jobs, not `whenever`/cron — `config/schedule.rb` is present but left as the unused Rails default stub in every project that has it). The one universal recurring entry is an hourly `SolidQueue::Job.clear_finished_in_batches` prune. Kamal deploys default to running Solid Queue's supervisor **inside Puma** (`SOLID_QUEUE_IN_PUMA: true`) with a commented-out dedicated `job:` role as an opt-in scale-out path; only cora (deployed on Render, not Kamal) and diskman (LLM-only fiber worker) actually split job processing into separate service processes. Two outliers use different backends entirely: `every` (an older Heroku-deployed app) runs Sidekiq + Redis with no cron/scheduler gem at all, and `lifegarden` runs GoodJob. `atelier` and `thinkroom` have no job backend gem installed — ActiveJob falls back to the default `:async` in-process adapter. `leva` and `blazer-ai` are mountable engines with no opinion on the adapter; they define jobs (`Leva::ApplicationJob < ActiveJob::Base`) and leave `queue_adapter` to the host app.

## Per-project breakdown

### cora
- Gemfile: `gem "solid_queue", "~> 1.1"` plus `gem "mission_control-jobs", "~> 1.0"` (admin UI).
- `config/queue.yml`: single default worker pool, `queues: ENV["SOLID_QUEUE_QUEUES"] || "high,default,puppeteer,mailers,heya,low"`, `threads: RAILS_MAX_THREADS (10)`, `processes: JOB_CONCURRENCY (1)`, `polling_interval: 0.1`; dispatcher `polling_interval: 1`, `batch_size: 500`; `preserve_finished_jobs: true`, `clear_finished_jobs_after: 12.hours` (30 days in dev).
- `config/recurring.yml`: ~25 scheduled entries, e.g. `prune_old_solid_queue_jobs` (hourly, `SolidQueue::Job.clear_finished_in_batches`), `record_database_metrics`/`record_solid_queue_metrics` (every minute), `auto_scale_solid_queue_workers` (every 15s), `refresh_google_tokens` (every 20 min), `gmail_pubsub_pull` (every 10s), `draft_brief_cutover` (every 15 min, with a documented thundering-herd-avoidance strategy in comments).
- `config/schedule.rb` exists but is the unused `whenever` gem stub (not wired up).
- Deploy: `config/deploy.yml` is unused Kamal boilerplate (`service: my-app`, `image: your-user/my-app`) — cora actually deploys via **Render** (`render.yaml`). Render defines a `cora-rails` web service plus two dedicated Solid Queue worker `pserv` services: `cora-solid-queue-worker-private` (`bin/jobs --skip-recurring`) and `cora-solid-queue-puppeteer-private` (`SOLID_QUEUE_QUEUES=puppeteer,solid_queue_recurring`) — i.e. the recurring scheduler is pinned to the puppeteer worker.
- `Procfile`: `solid_queue_worker: bin/jobs` (separate process for local/alt deploys), `web: bin/rails server`.
- Jobs: 80+ files in `app/jobs/`, namespaced subfolders (`inbox/`, `inbox_contacts/`, `inbound_webhooks/`), shared `app/jobs/concerns/` (`job_throttling.rb` using Pecorino for rate limiting at enqueue/perform time, `job_cancelation.rb`, `universal_concurrency_control.rb`, `appsignal_tagging.rb`, `turbo_request_id_propagation.rb`).

### atelier
- No job backend gem in Gemfile.
- No `config/queue.yml`, `config/recurring.yml`.
- `config/environments/production.rb` has `# config.active_job.queue_adapter = :resque` commented out (default Rails stub) — ActiveJob uses the default `:async` in-process adapter.
- No `app/jobs/` directory found.

### tada
- Gemfile: `gem "solid_queue"`.
- `config/queue.yml`: worker `queues:` computed conditionally — `TADA_PUBLISH_WORKER=true` role drains `"*"`; every other role drains an explicit allowlist `"default,solid_queue_recurring"`. Extensive inline comment explains this is a credential-isolation mechanism (the publish worker role is the only place holding a GitHub credential, so only it should run `CartridgePublishJob`). `threads: 3`, `processes: JOB_CONCURRENCY (1)`.
- `config/recurring.yml`: production-only block with 8 entries — hourly finished-job prune, `sweep_stalled_publish_requests` (every 5 min), `reap_publish_requests`/`reap_publish_audits` (daily ~3:10/3:20am), several OAuth reapers (`reap_oauth_pending_authorizations` hourly, `reap_oauth_access_tokens`/`reap_oauth_grants`/`reap_oauth_clients` daily), `clean_file_cache` (daily), `gc_publish_workspace` (daily). Comments cite a `test/recurring_schedule_test.rb` that evaluates each command for real.
- Deploy: `config/deploy.yml` — dynamic `KAMAL_SERVICE`/`KAMAL_IMAGE`, conditional `publish_worker` role gets the full `bin/jobs` supervisor; the `web` role only runs `SOLID_QUEUE_IN_PUMA` when no worker role is present.
- Jobs: minimal — `app/jobs/ai_key_health_transition_job.rb`, `cartridge_publish_job.rb`, `application_job.rb`.

### diskman
- Gemfile: `gem "solid_queue"`.
- `config/queue.yml`: `queues: "*"`, `threads: 3`, `processes: JOB_CONCURRENCY (1)`.
- `config/recurring.yml`: hourly prune, `schedule_library_syncs` (every 12 hours), `refresh_shop_recommendations` (at 8am daily).
- Notable hybrid: `app/jobs/llm_application_job.rb` is a separate ActiveJob base class that overrides `self.queue_adapter = :async_job` (the `async-job-adapter-active_job` gem, fiber-based) so LLM/RubyLLM jobs run on a dedicated fiber worker instead of Solid Queue thread workers — comment: "so work can run on the fiber-based job server instead of occupying Solid Queue thread workers."
- `Procfile.dev`: separate `async_job: bundle exec async-job-adapter-active_job-server` process plus `redis`.
- Deploy: `config/deploy.yml`, `service: diskman`, `image: kieranklaassen/diskman`, deployed to Kamal host `cora-hetzner`. Roles: `web` (main) and `llm_jobs` (dedicated Async::Job worker, same host). Env: `SOLID_QUEUE_IN_PUMA: true`, `WEB_CONCURRENCY: "1"` (SQLite single-writer constraint). Uses a Valkey Kamal accessory for Async::Job's Redis-compatible queue.
- Jobs organized flat in `app/jobs/`: `sync_apple_music_library_job.rb`, `sync_spotify_library_job.rb`, `import_last_fm_history_job.rb`, `fetch_cover_art_job.rb`, etc.

### lifegarden
- Gemfile: `gem "good_job", "~> 4.0"` (only GoodJob user in the survey).
- `config/environments/development.rb` and `production.rb`: `config.active_job.queue_adapter = :good_job`.
- `Procfile.dev`: `job: bundle exec good_job start`, `GOOD_JOB_MAX_THREADS: "5"`.
- `config/schedule.rb` present but unused `whenever` stub; no GoodJob cron config found.
- Jobs: `app/jobs/message_response_job.rb`, `app/jobs/database_backup_job.rb`, `application_job.rb`.

### thinkroom
- No job backend gem in Gemfile.
- `config/environments/production.rb` has the same commented-out `:resque` stub as atelier — default `:async` adapter.
- `app/jobs/` contains only the generated `application_job.rb` (no real jobs).

### riffrec-dashboard
- Gemfile: `gem "solid_queue", "~> 1.4"`.
- `config/queue.yml`: `queues: "*"`, `threads: 3`, `processes: JOB_CONCURRENCY (1)`; has a `staging:` environment key in addition to development/test/production.
- `config/recurring.yml`: separate `development:` and `production:` blocks (comment explains Solid Queue's `config_from` silently falls back to loading the whole file if the current env key is missing, so every scheduling env needs its own top-level key — dev needs its own copy of `clear_solid_queue_finished_jobs` too, "or its scheduler loads nothing at all"). Both envs: hourly prune + `run_status_poll` (`RunStatusPollJob`, every minute, `queue: default`).
- Deploy: `config/deploy.yml`, dynamic `KAMAL_HOSTS`; `WEB_CONCURRENCY: "1"` for SQLite single-writer. No dedicated job role found — Solid Queue runs in Puma.
- Jobs: `app/jobs/run_status_poll_job.rb`, `application_job.rb`.

### kieranklaassen-com
- Rails app (`gem "rails", "~> 8.1.3"`) but no job backend gem, no `config/queue.yml`/`recurring.yml`, no `app/jobs/` directory found. Effectively no background-job usage.

### leva
- Mountable Rails engine (gemspec-based), not an app — no `config/deploy.yml`, no `config/queue.yml`.
- Jobs live under `app/jobs/leva/` namespace: `Leva::ApplicationJob < ActiveJob::Base` (no adapter opinion), `experiment_job.rb`, `run_eval_job.rb`, `fine_tune_job.rb`, `prompt_optimization_job.rb`, each `queue_as :default`.
- Test dummy app (`test/dummy/config/environments/development.rb`) sets `queue_adapter = :async`; production env has the same commented-out `:resque` stub as atelier/thinkroom — confirms the engine intentionally defers the adapter choice to the host app.

### every
- Gemfile: `gem 'sidekiq', '~> 7.3.9'` — the only Sidekiq user in the survey.
- `config/sidekiq.yml`: `concurrency: ENV["SIDEKIQ_CONCURRENCY"] || 10`; `queues: [[default, 3], [email_trackers, 1]]` (weighted queue priority).
- `config/initializers/sidekiq.rb`: configures `Sidekiq.configure_server`/`configure_client` with `redis: { ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE } }` (needed for its Redis TLS setup) and syncs logger level.
- No sidekiq-cron, sidekiq-scheduler, whenever, or rufus-scheduler gem present — no recurring/scheduled job mechanism found at all.
- `Procfile`: `web`, `release: bundle exec rake db:migrate`, `sidekiq: bundle exec sidekiq`, `discord: bundle exec rake discord:listen` (a separate long-running listener process, not a job). No `config/deploy.yml` — deployed via Heroku (`app.json`, `Dockerfile.dev` present, no Kamal).
- Jobs: 30+ flat files in `app/jobs/` (`email_open_tracker_job.rb`, `deliver_post_job.rb`, `sync_convertkit_job.rb`, etc.), no subfolder namespacing.

### erf-rails
- Gemfile: `gem "solid_queue"`.
- `config/queue.yml`: `queues: "*"`, `threads: 3`, `processes: JOB_CONCURRENCY (1)`.
- `config/recurring.yml`: empty/commented-out template only (`# production: # periodic_cleanup: ...`) — no active recurring jobs configured.
- `config/schedule.rb` present but unused `whenever` stub.
- Deploy: `config/deploy.yml` is still unfilled Kamal boilerplate (`service: my-app`, `image: your-user/my-app`), with the same commented-out `job:` role and `SOLID_QUEUE_IN_PUMA: true` pattern seen in diskman/tada/riffrec-dashboard.
- Jobs: `app/jobs/` contains only `application_job.rb` — no real jobs defined yet.

### blazer-ai
- Mountable Rails engine (gemspec-based). No `app/jobs/` directory, no job backend gem, no deploy config. No background-job usage found.

## Recommendation for compound-stack-rails

1. **Adopt Solid Queue as the default ActiveJob backend.** It's the gem in 5 of the Rails apps surveyed (cora, tada, diskman, riffrec-dashboard, erf-rails) — the entire recent, Kamal/Rails-8-based cohort — versus one each on GoodJob (lifegarden) and Sidekiq (every, an older Heroku app), and two apps with no backend at all. It also needs no extra infra (Redis) beyond the database Kamal already provisions, which matches the single-server Kamal deploy story these apps use.
2. **Ship `config/queue.yml` with the shared shape**: a single `default` worker pool, `queues: "*"` (or an explicit env-driven allowlist for apps with credential-isolation needs, as tada demonstrates), `threads: 3`, `processes: ENV.fetch("JOB_CONCURRENCY", 1)`, `polling_interval: 0.1`, and a dispatcher block (`polling_interval: 1`, `batch_size: 500`). This exact block is nearly copy-identical across diskman, riffrec-dashboard, and erf-rails.
3. **Ship `config/recurring.yml` with one non-optional entry**: the hourly `SolidQueue::Job.clear_finished_in_batches` prune, present in every project that has any recurring config (cora, tada, diskman, riffrec-dashboard). Per riffrec-dashboard's documented gotcha, remind template users that each environment key (`development`, `production`, etc.) needs its own top-level entry in `recurring.yml` or Solid Queue's `config_from` silently loads nothing.
4. **Default Kamal deploy.yml to `SOLID_QUEUE_IN_PUMA: true`** with a commented-out dedicated `job:` role, matching diskman/erf-rails/tada's shared pattern — single-server by default, with an easy opt-in path to split out a worker role once queue depth demands it.
5. **Drop `config/schedule.rb` (whenever) entirely.** It appears in cora, lifegarden, erf-rails only as the untouched generator stub — nobody in the survey actually uses `whenever`/cron; Solid Queue's own `recurring.yml` is the real scheduler everywhere it's used.
6. **Keep jobs flat in `app/jobs/` by default**, following subfolder namespacing (`app/jobs/<domain>/`) only once a domain accumulates multiple jobs, as cora does with `inbox/`, `inbox_contacts/`, `inbound_webhooks/`. Ship `app/jobs/concerns/` as an extension point but don't pre-populate it with cora's throttling/cancellation modules — those depend on Pecorino, which is not a template-wide dependency.
