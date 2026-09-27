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

   # Loadout (required).
   export PUBLIC_BASE_URL=https://loadout.every.to
   export EVERY_OAUTH_BASE_URL=https://every.to
   export EVERY_OAUTH_CLIENT_ID=...       # Every OAuth client, redirect URI https://loadout.every.to/auth/every/callback
   export EVERY_OAUTH_CLIENT_SECRET=...
   export ADMIN_EMAILS=kieran@every.to

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

- Add an `A` record: `loadout.every.to` pointing at the server's IPv4 address (plus `AAAA` for IPv6 if present). kamal-proxy gets the certificate once DNS resolves.
- Register an Every OAuth client with redirect URI `https://loadout.every.to/auth/every/callback` and scope `basic_profile`.
- MCP clients discover the authorization server at `https://loadout.every.to/.well-known/oauth-authorization-server`. Nothing to register; clients self-register.

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

## Caveat: git worktrees do not inherit your shell secrets

`.kamal/deploy.env` is per-checkout and gitignored. A **git worktree** created
for isolated work starts without it, and `config/master.key` is not copied into a
fresh worktree either. Before deploying from a worktree, re-create
`.kamal/deploy.env` and copy `config/master.key` into it — otherwise the render
fails loudly (which is the intended safety behavior, not a bug).
