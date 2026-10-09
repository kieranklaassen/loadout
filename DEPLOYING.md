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
   export ADMIN_EMAILS=kieran@every.to    # admin once that address signs in with Every

   # Optional — sensible defaults.
   # export KAMAL_REGISTRY_SERVER=ghcr.io
   # export EVERY_OAUTH_SCOPE=basic_profile   # default "openid basic_profile"; basic_profile alone turns automatic sign-in off
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
- Register an Every OAuth client for Toolbox alone (every.to admin → OAuth Clients → New):
  - name `Toolbox`;
  - redirect URI `https://toolbox.every.to/auth/every/callback`, exactly;
  - scopes `basic_profile openid`.

  Toolbox asks for `openid basic_profile`. A client without `openid` makes every.to show an
  invalid-scope error instead of signing in; if `openid` cannot be added, set
  `EVERY_OAUTH_SCOPE=basic_profile`. Sign-in reads the person's name, photo and email. Any
  `@every.to` address is the Every team and `ADMIN_EMAILS` grants admin; every.to sends no
  `email_verified` claim, and only an explicit `false` is refused.
- A browser that is signed in to every.to can be signed in to Toolbox by itself; see
  "Automatic sign-in" below for what every.to must have set first.
- MCP clients discover the authorization server at `https://toolbox.every.to/.well-known/oauth-authorization-server`. Nothing to register; clients self-register.

## Automatic sign-in

A browser that is signed in to every.to is signed in to Toolbox by itself: every page asks
every.to once, with `prompt=none`, in a hidden frame, and the visitor stays on the page whatever
the answer. The sign-in page asks the same by redirect before it shows, which also covers a
signed-out visit to a page that needs sign-in. Do these three in order, or every.to answers
`consent_required` or `login_required` and nothing happens:

1. every.to runs the change that adds "Skip the consent page" to an OAuth app (EveryInc/every
   `0a9751e8`, with its migration).
2. In every.to's admin, tick "Skip the consent page" on the Toolbox client and add `openid` to
   its scopes.
3. Set `EVERY_OAUTH_SCOPE=openid basic_profile` (the default when the variable is unset) and
   deploy. Doing this before step 2 breaks every sign-in with an `invalid_scope` error. With
   `basic_profile` alone the whole of automatic sign-in is off: no frame, no redirect.

A "not signed in" answer stands for a day, a failed attempt for ten minutes (the
`every_silent_tried` cookie). Signing out of Toolbox sticks until that person clicks "Sign in
with Every" again. A session that began automatically lasts until sign-out, like any other, even
if the browser later signs out of every.to. Someone signed in this way for the first time is
taken to `/welcome` to finish onboarding, as after a clicked sign-in.

Check it after the deploy:

1. In a fresh browser profile, sign in at every.to with an account that has finished onboarding
   on Toolbox, then open `https://toolbox.every.to/`. Within a few seconds the header shows you,
   with no click and no navigation. Do it in Chrome, Safari and Firefox: the answer comes back
   through a hidden frame, and every.to must answer `/oauth/authorize?...&prompt=none` with a
   redirect, not a page, for the frame to get it.
2. If nothing happens, the logs say `every silent sign-in failed: <reason>` for a failure and
   nothing for a plain "not signed in"; a frame that never answers leaves no line at all.
3. Sign out of Toolbox and reload: you stay signed out.
4. Do it once more in a profile that has visited Toolbox before (sign out of Toolbox, clear its
   cookies but keep its site data, reload): the service worker is installed on a second visit,
   and the frame must get through with it there.
5. With an Every account that is new to Toolbox, open the home page: you are taken to `/welcome`.

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
After deploying, before you call it done:

1. **`/up` answers 200 with a container-IP `Host`.** In `bin/kamal shell`, run
   `curl -si -H "Host: 172.18.0.2" http://localhost/up` (any IP address will do) and expect
   `200`. The same request to any other path is refused.
2. **A real `@every.to` sign-in is the Every team.** Sign in once with a real staff account
   (you pass every.to's consent screen once), then check in `bin/kamal console` that
   `User.find_by(email_address: "you@every.to").every_member?` is `true`, and `admin?` too for an
   `ADMIN_EMAILS` address.
3. **Existing sessions must sign out and in once.** `email_verified` is set at each Every sign-in
   and defaults to false, so a row from before this release counts as "Everyone else", and an
   admin lacks admin, until that person signs in again.
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
