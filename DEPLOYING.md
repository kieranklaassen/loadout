# Deploying

This app deploys with [Kamal](https://kamal-deploy.org) 2.12+. `config/deploy.yml`
is fully env-driven: every tenant-specific value is read from the environment
with **no default**, so a missing variable fails the deploy loudly instead of
silently reusing another app's config.

## One-time setup

1. Create `.kamal/deploy.env` (gitignored) with this app's values:

   ```sh
   # Required — the render fails loudly if any of these is unset.
   export KAMAL_SERVICE=my-app
   export KAMAL_IMAGE=me/my-app   # WITHOUT the registry host — registry.server (ghcr.io) is prepended
   export KAMAL_WEB_HOST=203.0.113.10
   export KAMAL_PROXY_HOST=my-app.example.com
   export KAMAL_REGISTRY_USERNAME=me
   export KAMAL_STORAGE_VOLUME=my_app_storage
   export KAMAL_BUILDER_ARCH=amd64
   export KAMAL_SSH_USER=deploy

   # Toolbox (required).
   export PUBLIC_BASE_URL=https://toolbox.every.to   # the https origin, no path; see "PUBLIC_BASE_URL" below
   export EVERY_OAUTH_BASE_URL=https://every.to
   export EVERY_OAUTH_CLIENT_ID=...       # Every OAuth client, redirect URI https://toolbox.every.to/auth/every/callback
   export EVERY_OAUTH_CLIENT_SECRET=...
   export ADMIN_EMAILS=kieran@every.to    # an address is admin only once Every verified it

   # Optional — sensible defaults.
   # export KAMAL_REGISTRY_SERVER=ghcr.io
   # export RIFFREC_ENDPOINT=https://riffrec.example.com   # blank → capture off
   ```

2. Ensure `config/master.key` exists locally (untracked — see `.gitignore`).
   A fresh clone CANNOT decrypt the template's `config/credentials.yml.enc` —
   regenerate the pair for your tenant:

   ```sh
   rm config/credentials.yml.enc
   EDITOR=true bin/rails credentials:edit   # writes a new .enc + master.key
   ```

   Commit the new `credentials.yml.enc`; the key stays untracked.

## DNS and Every OAuth (one time, before `kamal setup`)

- Add an `A` record: `toolbox.every.to` pointing at the server's IPv4 address (plus `AAAA` for IPv6 if present). kamal-proxy gets the certificate once DNS resolves.
- Register an Every OAuth client with redirect URI `https://toolbox.every.to/auth/every/callback` and scope `basic_profile`. Sign-in reads the person's name, photo and email, and "Every team" needs the provider to send `email_verified: true` (see the first-deploy checks below).
- MCP clients discover the authorization server at `https://toolbox.every.to/.well-known/oauth-authorization-server`. Nothing to register; clients self-register.

## Deploy

```sh
source .kamal/deploy.env
bin/kamal setup     # first time
bin/kamal deploy    # subsequent deploys
```

Secrets (`.kamal/secrets`) are resolved at deploy time via shell indirection —
`$(gh auth token)` for the registry, `$(cat config/master.key)` for the master
key, `$RIFFREC_API_KEY` from the environment. No raw credential is ever
committed.

## PUBLIC_BASE_URL

`PUBLIC_BASE_URL` is required in production, and it is the single host knob. The OAuth issuer
and redirect, the MCP resource, share links and every host printed on a page derive from it, so
moving the app is a configuration change (moving it to `every.to/toolbox` is a separate deploy
task). Two things depend on it at boot:

- **Host authorization.** Production answers only to the host in `PUBLIC_BASE_URL`; a request with
  any other `Host` header is refused. `/up` is exempt, because kamal-proxy calls the container
  by IP.
- **A hard requirement.** The app raises at boot without it. The image build is exempt
  (`assets:precompile` runs with `SECRET_KEY_BASE_DUMMY`), so `docker build` needs no value.

`VIBE_CHECK_HOSTS` is optional. A model's Vibe Check link must be https on `every.to` or
`checks.every.to`; setting `VIBE_CHECK_HOSTS` (comma separated, exact hosts) replaces those two.
Kamal passes into the container only what `env` in `config/deploy.yml` lists, and that file does
not list this variable, so add it under `env.clear` there before you set it.

## What starting a container does

`bin/docker-entrypoint` runs these steps before the server, on every start:

0. **Render server.** Starts `bin/ssr` in the background, so it boots while the database is
   prepared. It runs `node public/vite-ssr/ssr.js` (built by `assets:precompile`, with every
   dependency bundled in, so the image needs only the `node` binary) on port 13714 and starts it
   again if it exits. After the catalog sync the entrypoint waits up to 10 seconds for the port,
   then starts Rails either way. Server rendering is on by default in production; if the render
   server is down or slower than `INERTIA_SSR_TIMEOUT` (2 seconds), that request falls back to
   client rendering. Set `INERTIA_SSR_ENABLED=false` to turn it off: no render server starts and
   Rails does not call it. Both run in the one container, so there is no second Kamal role.
1. **Backup.** If the database exists and migrations are pending, take a consistent copy with
   sqlite3 `.backup` to `storage/backup-<UTC timestamp>.sqlite3` (mode 0600). Nothing is backed
   up when nothing is pending, and a new database has nothing to back up. Only
   `production.sqlite3` is copied; the cache, queue and cable databases are not touched by these
   migrations.
2. **`db:prepare`.** Creates or migrates the database.
3. **`Catalog::Sync`.** Applies `config/catalog.yml` (categories, tools, models, marks). A failed
   sync is logged and the server still starts, so a malformed catalog has to be caught before
   deploy: `test/services/catalog/sync_test.rb` loads the real file in the CI test job, and local
   `bin/ci` also runs `db:seed:replant`. Launch dates and Vibe Check links are admin-owned: Sync
   only fills them while they are blank on a model no admin has edited.

The redesign's migrations drop data by design: picks beyond three in a kind, duplicate tools in a
kind, notes, and the `other` kind's picks and history. What they drop is first written to
`storage/migration_archive/` as JSON (mode 0600) and counted in the migration log.

The backup and the archive both hold member emails and notes. **Once the deploy is verified,
delete them**: in `bin/kamal shell`, check `ls -l storage`, then
`rm -r storage/migration_archive storage/backup-*.sqlite3`. Copies off the server hold the same
private data, including any off-server backup of the storage volume taken before this cleanup;
delete or expire those too.

## First deploy of the redesign

The new container migrates while the old one is still serving, so the old code fails on the
dropped columns until cutover. Expect a short window of errors.

Before deploying:

- `config/deploy.yml` sets Kamal's `deploy_timeout` to 120 seconds (default 30), because the
  backup, the migrations and the catalog sync all run before the server can answer `/up`. Raise it
  there first if the database is large enough to need longer.
- Check that Every's UserInfo sends `email_verified: true` for staff. "Every team" and admin
  rights need it and both fail closed: without the claim, staff sign in but count as "Everyone
  else", and `ADMIN_EMAILS` grants nothing. If the claim is missing, choose the fallback (key the
  team on the Every user id) before shipping.

After deploying, before you call it done:

1. **`/up` answers 200 with a container-IP `Host`.** In `bin/kamal shell`, run
   `curl -si -H "Host: 172.18.0.2" http://localhost/up` (any IP address will do) and expect
   `200`. The same request to any other path is refused.
2. **A real `@every.to` sign-in sets `email_verified`.** Sign in once with a real staff account,
   then check in `bin/kamal console` that
   `User.find_by(email_address: "you@every.to").email_verified` is `true`.
3. **Existing sessions must sign out and in once.** `email_verified` is assigned from the
   provider's claim at each sign-in and defaults to false, so until someone signs in again they
   count as "Everyone else" and an admin loses admin.
4. **Revoke agent grants from before this release, if there are any.** In `bin/kamal console`,
   check `OauthGrant.active.exists?`. If it is `true`, run
   `bin/kamal app exec --reuse "bin/rails toolbox:revoke_agent_grants"`: an older grant keeps
   working, and its agent now reads teammates' shared picks. Members approve their agents again.
5. **Set launch links.** Add each model's release date and Vibe Check link at
   `/admin/catalog_items`; a model is listed as a launch only with both.
6. **Delete the backup and the migration archive**, and any off-server copy of them (see above).

## Rollback

There is no rollback to the previous image once the schema has changed: the old code reads
columns the migration dropped. If the new container fails its health check, Kamal keeps the old
container running, but the migration has already run and the old code cannot use the new schema.
Fix forward if you can. Otherwise rollback means restoring the backup:

1. `bin/kamal app stop`.
2. Copy `storage/backup-<timestamp>.sqlite3` over `storage/production.sqlite3`, and remove
   `production.sqlite3-wal` and `production.sqlite3-shm` beside it. The volume is
   `KAMAL_STORAGE_VOLUME`, mounted at `/rails/storage`; `bin/kamal app exec "..."` runs a one-off
   container with it mounted.
3. Start the previous version (`bin/kamal rollback <version>`, or redeploy the old commit).

Anything written after the backup is lost, and the backup is the only way back, so do not delete
it until you are sure.

## Operating

Two rake tasks run in the container (`bin/kamal app exec --reuse "..."`):

- `EMAIL=person@every.to bin/rails toolbox:remove_member` removes a member who left Every: the
  same deletion as Settings, so their picks, history, suggestions, visibility periods, sessions
  and agent connections go too. Someone who leaves Every without deleting their account stays in
  "Every team" counts and readable until you run this. Tools and models they added stay in the
  catalog.
- `bin/rails toolbox:revoke_agent_grants` revokes every agent connection and withdraws the
  suggestions agents left open, so members approve their agents again. Use it if agents connected
  before this release: there is one `toolbox` scope, and reads now include teammates' data.

## Caveat: git worktrees do not inherit your shell secrets

`.kamal/deploy.env` is per-checkout and gitignored. A **git worktree** created
for isolated work starts without it, and `config/master.key` is not copied into a
fresh worktree either. Before deploying from a worktree, re-create
`.kamal/deploy.env` and copy `config/master.key` into it — otherwise the render
fails loudly (which is the intended safety behavior, not a bug).
