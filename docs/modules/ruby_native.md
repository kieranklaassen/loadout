# Module: ruby_native

[Ruby Native](https://rubynative.com/) distribution: turn the app into real
native iOS/Android apps (native tab bars, navigation, sheets, push
notifications) without Swift/Kotlin. Works with any Rails frontend, including
this template's Inertia/React stack.

## What this module is

Ruby Native is a **paid, per-app product** ($299+/year), so the template ships
this module **documentation-first**: adoption conventions and placeholder
configuration, no gem installed and no license anywhere in the repo. Adopting
the module means running Ruby Native's own generator in the app and keeping its
config in the shape documented here.

## Files (the module boundary)

- `docs/modules/ruby_native.md` — this doc (the module is doc-first in the template).
- After adoption in an app: the `ruby_native` gem in the `Gemfile`,
  `config/ruby_native.yml` (generator-created), and any generated native shells.

## Invariant: no license keys, no store credentials

Same rule as riffrec: nothing secret in the repo. License/API keys live in env
vars or credentials, never in `config/ruby_native.yml` committed to git.
`.env.example` may carry key names only.

## Adopt into an existing app

1. Purchase/activate a Ruby Native license for the app (per-app pricing).
2. Add the `ruby_native` gem to the `Gemfile` and `bundle install`.
3. Run the Ruby Native generator; review the generated `config/ruby_native.yml`.
4. Move any key/license values it wants into env vars; commit only placeholders.
5. Add `ruby_native` to the app's `.template-manifest.yml` at the current
   template version.

## Verify adoption

- `bundle list | grep ruby_native` shows the gem.
- `config/ruby_native.yml` exists and contains no secrets (`git grep -iE "(api|license)_?key.*['\"][A-Za-z0-9]{12}" config/ruby_native.yml` is empty).
- `bin/rails test` stays green.
