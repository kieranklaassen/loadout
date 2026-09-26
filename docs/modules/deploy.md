# Module: deploy

Kamal 2.12+ deploy, fully env-driven. `config/deploy.yml` reads every
tenant-specific value from `ENV.fetch` with **no default**, so a missing variable
fails the render loudly instead of silently reusing another tenant's config.

## What this module is

- `config/deploy.yml` — ERB-templated on `KAMAL_*` env vars. Required (no
  default): `KAMAL_SERVICE`, `KAMAL_IMAGE`, `KAMAL_WEB_HOST`, `KAMAL_PROXY_HOST`,
  `KAMAL_REGISTRY_USERNAME`, `KAMAL_STORAGE_VOLUME`, `KAMAL_BUILDER_ARCH`,
  `KAMAL_SSH_USER`. Defaulted: `KAMAL_REGISTRY_SERVER` (`ghcr.io`),
  `RIFFREC_ENDPOINT` (blank → capture off).
- kamal-proxy with `ssl: true` + `healthcheck.path: /up`; `minimum_version: 2.12.0`.
- Single `web` role (`SOLID_QUEUE_IN_PUMA: true`, `WEB_CONCURRENCY: "1"`), with a
  commented-out `job` role as the documented scale path.
- SQLite storage volume at `/rails/storage`; `asset_path: /rails/public/vite`.
- `Dockerfile`: `ruby:4.0.7-slim`, installs `sqlite3`, `EXPOSE 80`,
  `CMD ["./bin/thrust", "./bin/rails", "server"]` (Thruster on port 80).
- `.kamal/secrets`: shell-indirection **placeholders only** —
  `$(gh auth token)`, `$(cat config/master.key)`, `$RIFFREC_API_KEY`. No raw
  credential is ever committed.

## Why no defaults for tenant keys

On a shared host, a `deploy.yml` that falls back to a default `service`/`image`/
`host` when a var is unset will happily deploy one app's code under another app's
identity — a config leak. Failing the render loudly is the only shape that
prevents it. `test/deploy_config_test.rb` asserts both the successful render and
the `KeyError` on a missing key.

## Files (the module boundary)

- `config/deploy.yml`, `.kamal/secrets`, `Dockerfile`, `.dockerignore`
- `bin/thrust`, `bin/kamal`, `bin/docker-entrypoint`
- `DEPLOYING.md`, `test/deploy_config_test.rb`

## Adopt into an existing app

1. Copy `config/deploy.yml`, `.kamal/secrets`, `Dockerfile`, and `DEPLOYING.md`.
2. Create `.kamal/deploy.env` (gitignored) with the required `KAMAL_*` values
   (see `DEPLOYING.md`).
3. Confirm `bin/thrust` / `bin/kamal` binstubs exist (`bundle binstubs kamal thruster`).

## Verify adoption

- `bin/rails test test/deploy_config_test.rb`
- `source .kamal/deploy.env && bin/kamal config` renders without error.

See `DEPLOYING.md` for the full runbook and the git-worktree secrets caveat.
