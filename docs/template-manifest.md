# The template manifest

`.template-manifest.yml` (repo root) records which template version an app is on
and which modules it has adopted. It is the machine-readable contract an upgrade
agent reads.

## Schema

```yaml
template_version: "0.1.0"   # semver; the template version this app is on
modules:                    # module name -> the template_version it was adopted at
  auth: "0.1.0"
  deploy: "0.1.0"
```

- `template_version` — a semver string. For the template itself this is the
  current version; for a downstream app it is the version its manifest was last
  bumped to.
- `modules` — a map of module name → the `template_version` at which the app
  adopted that module. A module's name is exactly its `docs/modules/<name>.md`
  basename.

Validated by `test/template/manifest_test.rb`: the file parses, `template_version`
is valid semver, every adopted-at value is valid semver no newer than
`template_version`, and (for the template itself) the keys match `docs/modules/*.md`
1:1.

## Born-complete (R7)

The template ships its **own** manifest listing **every** module at the current
`template_version`. So a new app cloned from the template inherits a complete
manifest and starts fully adopted — nothing to wire up.

## À la carte adoption (R8)

A downstream app that did not start from the template lists only the modules it
has actually adopted. Adopting a module (see each module doc's "Adopt into an
existing app") means adding its key at the current `template_version`.

## Renaming a clone

The template's app module is `CompoundStackRails` (from the repo name). A new app
renames it — update `config/application.rb`, `config/database.yml` database names,
`config/cable.yml`, the Kamal `KAMAL_SERVICE`/`KAMAL_IMAGE` env values, and
`config/initializers/pwa.rb` (the user-facing app name, short name, description,
and colours that feed the web app manifest, `<title>`, and `application-name`).
The manifest/changelog machinery is name-agnostic and needs no change.

## Upgrade flow

An upgrade agent, given the app repo and the template repo:

1. reads the app's `.template-manifest.yml` (version + adopted modules);
2. selects changelog entries with `template_version` newer than the app's, whose
   affected modules intersect the app's adopted modules;
3. applies them in order;
4. bumps `template_version` in the manifest;
5. opens a reviewable PR (never a direct push).
