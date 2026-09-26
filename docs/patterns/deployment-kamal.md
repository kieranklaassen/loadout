# Deployment (Kamal) — pattern survey

Surveyed 12 of Kieran Klaassen's projects for `config/deploy.yml`, `Dockerfile`, `.kamal/secrets`, and any non-Kamal deploy config. Facts only — no generic Kamal/Rails knowledge padded in.

## Summary of the dominant pattern

Six actively-maintained apps (tada, diskman, lifegarden, thinkroom, riffrec-dashboard, kieranklaassen-com) share one deliberate, hand-built Kamal 2.11/2.12 pattern: a single Hetzner box (`cora-hetzner`, SSH user `ubuntu`) running **kamal-proxy** (not Traefik) fronting multiple tenants, image pushed to **ghcr.io** with `KAMAL_REGISTRY_PASSWORD=$(gh auth token)`, one `web` role plus an optional dedicated `job`/`llm_jobs` role, SQLite-backed storage (`WEB_CONCURRENCY: "1"`, a single named volume mounted at `/rails/storage`) except lifegarden which runs Postgres as a Kamal accessory, `asset_path: /rails/public/vite` (Vite frontends, not Sprockets), and `RAILS_MASTER_KEY`/`CURSOR_API_KEY`/API keys delivered via `env.secret` resolved from `.kamal/secrets` shell indirection (`$(gh auth token)`, `$(cat config/master.key)`, `$VAR`). Four of these six (tada, thinkroom, riffrec-dashboard, kieranklaassen-com) go further and templatize the entire `deploy.yml` with ERB reading `ENV.fetch("KAMAL_...")` for service name, image, hosts, proxy hosts, registry, builder arch, and SSH user, so the file itself carries no machine-specific data and is safe to keep identical across environments/tenants. Two older/scaffolded projects (cora, erf-rails) still carry the **unmodified Kamal jumpstart-pro template** (literal `service: my-app`, `image: your-user/my-app`, placeholder `192.168.0.1` hosts) alongside a Heroku `app.json` — meaning Kamal is present in the Gemfile/repo but not actually the live deploy path for those two. atelier, leva, and blazer-ai have no deployment config at all (leva and blazer-ai are gems; atelier is a dev tool with no Dockerfile/deploy.yml). every.to has no Kamal or Dockerfile for production at all — only `Dockerfile.dev` plus a Heroku `app.json`, i.e. it deploys to Heroku, not Kamal.

## Per-project breakdown

### cora
- `config/deploy.yml` present but is the **stock, unedited Kamal/Jumpstart-Pro template**: `service: my-app`, `image: your-user/my-app`, `servers.web: [192.168.0.1]`, commented-out `job` role, Postgres 16 + Redis 7 as accessories on `192.168.0.1`. Not machine-specific — looks unused for real deploys.
- `Dockerfile` present, multi-stage, `ruby:3.3-slim`, installs `libjemalloc2 libvips postgresql-client`, Node 22.11.0/Yarn 1.22.22 via node-build, non-root user `rails` (uid 1000), `ENTRYPOINT ["/rails/bin/docker-entrypoint"]`, `CMD ["./bin/rails","server"]`. Standard Rails 7-era Dockerfile (Jumpstart Pro boilerplate).
- `.kamal/secrets`: **not present**.
- `Gemfile.lock`: `kamal (1.8.1)` — Kamal 1, the oldest version seen.
- Real deploy path is Heroku: `app.json` (`"image": "heroku/ruby"`, addons `heroku-postgresql:mini`, `heroku-redis:mini`, `scheduler:standard`, buildpacks for apt/vips/jemalloc/nodejs/ruby).
- `ops/render/` exists but only contains a Tailscale subnet-router Render service (infra, not the app itself).

### atelier
- No `config/deploy.yml`, no `Dockerfile`, no `.kamal/`. Not deployed via Kamal (or anything found) — appears to be a local dev tool.

### tada
- `config/deploy.yml`: fully ERB-templated, `minimum_version` not set but `Kamal 2.12` per Gemfile. Reads `KAMAL_SERVICE`, `KAMAL_IMAGE` (format `OWNER/tada`, comment explicitly warns against double-prefixing with `ghcr.io/`), `KAMAL_HOSTS`, `KAMAL_PROXY_HOSTS` via a `required_list` ERB helper that raises if empty.
- Single `web` role; a second `worker` role is conditionally rendered only when a GitHub publish credential (`GITHUB_APP_ID`+`GITHUB_APP_PRIVATE_KEY_B64` or `GITHUB_PUBLISH_TOKEN`) is exported — runs `cmd: bin/jobs`, `proxy: false`, its own scoped volume (`KAMAL_PUBLISH_WORKSPACE_VOLUME`, default `tada_publish_workspace`) mounted at `/rails/publish-workspace`.
- `proxy: { ssl: true, response_timeout: 120, hosts: <KAMAL_PROXY_HOSTS> }` — kamal-proxy, long timeout for AI actions.
- `registry: { server: ENV.fetch("KAMAL_REGISTRY_SERVER","ghcr.io"), username: KAMAL_REGISTRY_USERNAME, password: [KAMAL_REGISTRY_PASSWORD] }`.
- Extensive `env.secret`/`env.clear` list gated by ERB conditionals: `RAILS_MASTER_KEY`, `TADA_INVITE_CODES`, `RIFFREC_API_KEY`, 3x `AR_ENCRYPTION_*` keys (validated non-empty at ERB-render time, not just deploy time), optional `SMTP_PASSWORD`, `GEMINI_API_KEY`, optional `TADA_HOUSE_AI_GEMINI_API_KEY`.
- `volumes: ["<KAMAL_STORAGE_VOLUME>:/rails/storage"]`, `asset_path: /rails/public/vite`, `builder.arch: ENV.fetch("KAMAL_BUILDER_ARCH","amd64")` with optional `builder.remote`, `ssh.user: ENV.fetch("KAMAL_SSH_USER","root")`.
- `Dockerfile`: `ruby:3.4.2-slim`, `check=error=true` syntax directive, installs `sqlite3`, `EXPOSE 80`, `CMD ["./bin/thrust", "./bin/rails", "server"]` (uses `thruster`).
- `.kamal/secrets`: shell-indirection pattern (`$KAMAL_REGISTRY_PASSWORD`, etc.), heavily commented, opt-in secrets paired with matching `env.secret` lines.
- `Gemfile`: `gem "kamal", "~> 2.12.0"` → locked `kamal (2.12.0)`.
- `DEPLOYING.md` present at repo root documenting the `.kamal/deploy.env` convention.

### diskman
- `config/deploy.yml`: **not templatized** — hardcoded values. `service: diskman`, `image: kieranklaassen/diskman`, `servers.web: [cora-hetzner]`, plus an `llm_jobs` role (`cmd: bundle exec async-job-adapter-active_job-server`) for RubyLLM-heavy background work (uses `async-job-adapter-active_job` gem, not Solid Queue/GoodJob).
- `proxy: { ssl: true, host: diskman.kieranklaassen.com }` — single host form (older-style `proxy.host` not `proxy.hosts`).
- `registry: { server: ghcr.io, username: kieranklaassen, password: [KAMAL_REGISTRY_PASSWORD] }`.
- `env.secret: [RAILS_MASTER_KEY]`; `env.clear`: `SOLID_QUEUE_IN_PUMA: true`, `WEB_CONCURRENCY: "1"` (SQLite), `REDIS_URL: redis://diskman-valkey:6379/0`.
- `volumes: ["diskman_storage:/rails/storage"]`, `asset_path: /rails/public/vite`.
- `builder: { arch: amd64, remote: ssh://ubuntu@cora-hetzner }` — cross-arch remote build from an arm64 Mac.
- `accessories.valkey`: `valkey/valkey:8` image (not `redis`), `network: kamal`, `roles: [web, llm_jobs]`, `cmd: valkey-server --save "" --appendonly no` (no persistence), volume `valkey_data:/data`.
- `.kamal/secrets`: `KAMAL_REGISTRY_PASSWORD=$(gh auth token)`, `RAILS_MASTER_KEY=$(cat config/master.key)`.
- `Gemfile.lock`: `kamal (2.11.0)`.
- Docs: `docs/operations/deploy-sqlite.md` referenced inline for the single-writer SQLite caveat.

### lifegarden
- `config/deploy.yml`: hardcoded. `service: lifegarden`, `image: kieranklaassen/lifegarden`, `servers.web: [cora-hetzner]`, `job` role running `cmd: bundle exec good_job start` (GoodJob, not Solid Queue), `stop_timeout: 30`.
- `proxy: { ssl: ENV.fetch("KAMAL_PROXY_SSL","true")=="true", hosts: [lifegarden.app, www.lifegarden.app], app_port: 3000, healthcheck: { path: /up } }` — the **only reviewed project with an explicit Kamal `healthcheck.path`** in this survey besides riffrec-dashboard/kieranklaassen-com's `/up`.
- **Only project using Postgres as the primary datastore via a Kamal accessory** rather than SQLite: `accessories.postgres` (`postgres:15-bookworm`, `host: cora-hetzner`, custom init script `config/postgres/init-cable.sql` to create a second `cable` DB, `restart: always`).
- `env.secret`: `RAILS_MASTER_KEY`, `DATABASE_URL`, `CABLE_DATABASE_URL`, `GEMINI_API_KEY`. `env.clear`: `WEB_CONCURRENCY: "1"`, `RAILS_MAX_THREADS: "5"`, `GOOD_JOB_MAX_THREADS: "5"`, plus RubyLLM model/timeout and database-backup config.
- `builder: { arch: amd64, remote: ssh://ubuntu@cora-hetzner }`.
- `.kamal/secrets` composes `DATABASE_URL`/`CABLE_DATABASE_URL` from a `security find-generic-password` (macOS Keychain) lookup for the Postgres password.
- `Dockerfile`: `ruby:${RUBY_VERSION}-slim`, `EXPOSE 3000`, `CMD ["./bin/rails","server"]` (no thruster — direct Puma on 3000, matching `app_port: 3000` in deploy.yml). Also has separate `Dockerfile.dev` and `docker-compose.yml`.
- `Gemfile.lock`: `kamal (2.12.0)`.

### thinkroom
- `config/deploy.yml`: fully ERB-templated, same shape as tada (`KAMAL_SERVICE`, `KAMAL_IMAGE`, `KAMAL_HOSTS`, `KAMAL_PROXY_HOSTS`, `KAMAL_REGISTRY_SERVER` default `ghcr.io`, `KAMAL_REGISTRY_USERNAME`, `KAMAL_BUILDER_ARCH` default `amd64`, `KAMAL_BUILDER_REMOTE`, `KAMAL_SSH_USER` default `root`).
- `proxy: { ssl: true, buffering: { requests: true, responses: true, memory: 2_097_152, max_request_body: 67_108_864 } }` — explicit kamal-proxy buffering config, unique to this project among those reviewed.
- Single `web` role only, no job role.
- `env.secret: [RAILS_MASTER_KEY, CURSOR_API_KEY]` + optional `GOOGLE_CLIENT_ID`/`GOOGLE_CLIENT_SECRET` behind `KAMAL_GOOGLE_OAUTH=1`. `env.clear`: `WEB_CONCURRENCY: "1"`, `RIFFREC_AUTOMATION_EMAILS`.
- `volumes: ["<KAMAL_STORAGE_VOLUME>:/rails/storage"]`, `asset_path: /rails/public/vite`.
- `.kamal/secrets`: `KAMAL_REGISTRY_PASSWORD=$(gh auth token)`, `RAILS_MASTER_KEY=$(cat config/master.key)`, `CURSOR_API_KEY=$CURSOR_API_KEY`.
- `Dockerfile`: `ruby:$RUBY_VERSION-slim`, `EXPOSE 80`, `CMD ["./bin/thrust","./bin/rails","server"]` (thruster on port 80 behind kamal-proxy).
- `Gemfile.lock`: `kamal (2.12.0)`. `DEPLOYING.md` present.

### riffrec-dashboard
- `config/deploy.yml`: same ERB-templated shape as tada/thinkroom, but explicitly documents it is **the 5th tenant on a shared Hetzner host** (`cora-hetzner`) whose kamal-proxy already fronts four other production apps — every `ENV.fetch` deliberately has **no default** to force-fail a forgotten `source .kamal/deploy.env` rather than silently inherit another tenant's config.
- `proxy: { ssl: true, response_timeout: 100, hosts: <KAMAL_PROXY_HOSTS> }` — extended timeout for a slow third-party API call (Cursor repo listing).
- `env.secret: [RAILS_MASTER_KEY, CURSOR_API_KEY]`; `env.clear: { WEB_CONCURRENCY: "1" }`.
- `volumes: ["<KAMAL_STORAGE_VOLUME>:/rails/storage"]`, `asset_path: /rails/public/vite`.
- `builder.arch` has **no default** (`ENV.fetch("KAMAL_BUILDER_ARCH")`) — deliberately fails rather than assume amd64, since the dev machine is arm64.
- `ssh.user` also has **no default** (host uses `ubuntu`, not Kamal's `root` default).
- `.kamal/secrets`: `RAILS_MASTER_KEY=$(cat config/master.key)`, `KAMAL_REGISTRY_PASSWORD=$(gh auth token)` (documented as an intentional scope-broad fallback vs. a narrower PAT), `CURSOR_API_KEY`, `BOARD_PASSWORD` (basic-auth style credential that crashloops the container if unset/empty — fail-closed by design).
- `Dockerfile`: `ruby:$RUBY_VERSION-slim`, `EXPOSE 80`, `CMD ["./bin/thrust","./bin/rails","server"]`.
- `Gemfile.lock`: `kamal (2.12.0)`. `DEPLOYING.md` documents the shared-host stop/go gates.

### kieranklaassen-com
- `config/deploy.yml`: ERB-templated, smallest/simplest of the group — `minimum_version: 2.12.0` explicitly pinned (only project doing so). Single `web` role, `proxy: { ssl: true, hosts: <KAMAL_PROXY_HOSTS>, healthcheck: { path: /up } }`.
- `env.secret: [RAILS_MASTER_KEY]`; `env.clear: { APP_HOSTS: <KAMAL_PROXY_HOSTS> }`.
- No `volumes:` key present (no persistent storage declared) and no `builder` cross-build noted beyond arch/remote ERB defaults identical to tada/thinkroom.
- `asset_path: /rails/public/vite`.
- `.kamal/secrets`: `KAMAL_REGISTRY_PASSWORD=$(gh auth token)`, `RAILS_MASTER_KEY=$(cat config/master.key)` — nothing else, simplest secrets file in the survey.
- `Dockerfile`: `ruby:${RUBY_VERSION}-slim`, `EXPOSE 80`, `CMD ["./bin/thrust","./bin/rails","server"]`.
- `Gemfile.lock`: `kamal (2.12.0)`.

### leva
- No `config/deploy.yml`, no `Dockerfile`, no `.kamal/`. It's a Rails engine gem (`leva.gemspec`), not a deployed app.

### every
- No `config/deploy.yml`, no `.kamal/`, no production `Dockerfile` — only `Dockerfile.dev` and three `docker-compose.*.yml` files for local/worktree dev.
- `app.json` (Heroku): `"stack": "heroku-24"`, buildpacks `heroku/ruby` (+ `heroku-community/chrome-for-testing` and `heroku/nodejs` in the `test` environment for browser-driven specs), addon `heroku-postgresql:in-dyno` in test env.
- Deploys to **Heroku**, not Kamal.

### erf-rails
- `config/deploy.yml` present but is the **stock, unedited Jumpstart-Pro Kamal template** (`service: my-app`, `image: your-user/my-app`, `servers.web: [192.168.0.1]`, `proxy.host: app.example.com`, Postgres 17 accessory) — same unused-boilerplate situation as cora.
- Also has `render.yaml` — Render's own example blueprint (`services.web` on Render's `free`/`ruby` runtime, `buildCommand: ./bin/render-build.sh`, `healthCheckPath: /up`, four Postgres-backed databases for primary/solid_cable/solid_cache/solid_queue) — also appears to be an unedited example, not a live target.
- And an `app.json` (Heroku) nearly identical in shape to cora's.
- `.kamal/secrets` present and filled in (`KAMAL_REGISTRY_PASSWORD=$KAMAL_REGISTRY_PASSWORD`, `RAILS_MASTER_KEY=$(cat config/credentials/production.key)`, `POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-password}`) — more filled-in than cora's, but the `deploy.yml` itself is still template placeholders.
- `Dockerfile`: `ruby:$RUBY_VERSION-slim`, `EXPOSE 80`, `CMD ["./bin/thrust","./bin/rails","server"]`.
- `Gemfile.lock`: `kamal (2.10.1)`.
- Net effect: erf-rails carries **three parallel unused/half-used deploy configs** (Kamal template, Render example, Heroku app.json) — evidence of Jumpstart Pro scaffolding left in place rather than a chosen deploy path.

### blazer-ai
- No `config/deploy.yml`, no `Dockerfile`, no `.kamal/`. Rails engine gem (`blazer-ai.gemspec`), not a deployed app.

## Recommendation for compound-stack-rails

1. **Adopt the ERB-templated `deploy.yml` pattern** from tada/thinkroom/riffrec-dashboard/kieranklaassen-com: `service`/`image`/`servers.web.hosts`/`proxy.hosts`/`registry.username`/`builder.arch`/`ssh.user` all read from `ENV.fetch("KAMAL_...")`, most with no default so a missing var fails the deploy loudly instead of silently reusing another tenant's config (riffrec-dashboard's explicit shared-host rationale). This is the most mature and most-repeated pattern (4 of 6 real deployments) and is exactly what a multi-tenant starter template needs, since every generated app will share the same file shape.
2. **Default to ghcr.io as the registry** (`KAMAL_REGISTRY_SERVER` default `ghcr.io`, `KAMAL_REGISTRY_PASSWORD=$(gh auth token)` in `.kamal/secrets`) — used by all six real deployments, zero use of Docker Hub.
3. **Default to kamal-proxy, not Traefik** — every project reviewed uses Kamal 2's built-in `proxy:` stanza; Traefik does not appear anywhere in the survey.
4. **Ship a single `web` role by default with an optional second role gated by presence of a feature**, following tada's pattern (conditional `worker` role rendered only once a credential is exported) rather than diskman/lifegarden's always-on second role — this keeps the starter's default footprint to one container while still documenting the extension point.
5. **Default storage to SQLite with `WEB_CONCURRENCY: "1"` and a single named volume at `/rails/storage`**, since 5 of 6 real deployments (all but lifegarden) use SQLite this way; document lifegarden's Postgres-accessory pattern (`accessories.postgres` + a custom init SQL file for a second `cable` database) as the opt-in path for apps that need it.
6. **Use `asset_path: /rails/public/vite`** as the default (5 of 6 projects use Vite; only lifegarden is Sprockets and explicitly documents *why* it disables asset bridging) — matches an Inertia+Vite starter.
7. **Use `./bin/thrust ./bin/rails server` on `EXPOSE 80`** (thruster) as the container entrypoint, per tada/thinkroom/riffrec-dashboard/kieranklaassen-com/erf-rails — lifegarden's direct-Puma-on-3000 is the outlier and should not be the default.
8. **Pin `minimum_version: 2.12.0`** in `deploy.yml` as kieranklaassen-com does — it's the only project that pins, and 2.12.0 is what every actively-maintained project has locked in `Gemfile.lock`. Do not model the starter on cora/erf-rails, which still carry Kamal 1.8.1/2.10.1 stock templates that were never wired up for real deploys.
9. **Ship a `/up` healthcheck in `proxy.healthcheck.path`** (lifegarden, kieranklaassen-com) rather than leaving it unset (tada, thinkroom, riffrec-dashboard, diskman omit it) — cheap and only two of six projects bothered, so make it the template default rather than relying on each app author to add it.
10. **Ship a `.kamal/secrets` file using shell-indirection** (`$(gh auth token)`, `$(cat config/master.key)`, `$VAR`) with secrets never written to disk, matching all seven real deployments' pattern, plus a `DEPLOYING.md` documenting the `.kamal/deploy.env` sourcing step (present in tada, thinkroom, riffrec-dashboard, kieranklaassen-com).
11. **Do not include Heroku (`app.json`) or Render (`render.yaml`) config by default.** They appear only as either the *actual* deploy target for older/non-Kamal projects (cora, every, erf-rails) or as leftover unedited scaffolding (erf-rails' render.yaml, cora/erf-rails' Kamal templates) — none of the actively Kamal-deployed apps in this survey keep a parallel Heroku/Render config. A Kamal-first starter should commit fully to Kamal and drop the alternate-platform boilerplate that Jumpstart Pro leaves behind.
