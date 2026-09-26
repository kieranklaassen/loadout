# Idempotent: safe to run on every deploy (bin/docker-entrypoint runs db:prepare, which seeds a new database).
Catalog::Sync.call

load Rails.root.join("db/seeds/development.rb") if Rails.env.development?
