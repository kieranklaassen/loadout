# frozen_string_literal: true

InertiaRails.configure do |config|
  # Lambda so the asset version is re-read on each request rather than frozen at
  # boot — a rebuilt frontend invalidates client history without a server restart.
  #
  # The lock is load-bearing. ViteRuby.digest computes inside
  # ViteRuby::Config#within_root, which is `Dir.chdir(root) { ... }` — and
  # block-form Dir.chdir is PROCESS-WIDE. A second thread entering while the first
  # is inside raises "conflicting chdir during another chdir block", so under Puma
  # two concurrent Inertia requests 500. vite_ruby's own 1-second memo narrows that
  # window without closing it, and is itself read and written unsynchronized.
  #
  # development/test recompute on every call, so a rebuilt frontend still
  # invalidates client history. Everywhere else the watched files cannot change for
  # the life of the process (a rebuild ships a new container), so the first digest
  # is memoized and no later request pays for the glob + SHA1 again.
  vite_digest_lock = Mutex.new
  vite_digest = nil

  config.version = lambda do
    vite_digest_lock.synchronize do
      next ViteRuby.digest if Rails.env.local?

      vite_digest ||= ViteRuby.digest
    end
  end
  config.encrypt_history = true
  config.always_include_errors_hash = true
  config.use_script_element_for_initial_page = true
  config.use_data_inertia_head_attribute = true

  # --- SSR: on by default in production ---
  # `bin/rails assets:precompile` builds public/vite-ssr/ssr.js (ssrBuildEnabled in
  # config/vite.json) and bin/docker-entrypoint starts it beside Rails through
  # bin/ssr. The entrypoint branches CSR/SSR on data-server-rendered, and the render
  # call is bounded by config/initializers/inertia_ssr_timeout.rb. Any render failure
  # falls back to client rendering (see on_ssr_error). INERTIA_SSR_ENABLED=false
  # turns it off; development and test render on the client unless it is set true.
  config.ssr_enabled = ActiveModel::Type::Boolean.new.cast(ENV.fetch("INERTIA_SSR_ENABLED", Rails.env.production?))
  config.ssr_url = ENV.fetch("INERTIA_SSR_URL", "http://127.0.0.1:13714")
  config.ssr_bundle = Rails.root.join("public/vite-ssr/ssr.js").to_s

  # On any SSR failure, log the failing component and fall back to CSR rather
  # than surfacing an error to the user (ssr_raise_on_error stays false).
  config.on_ssr_error = lambda do |error, page|
    Rails.logger.error(
      "[inertia-rails] SSR render failed for #{page&.dig(:component) || 'unknown component'}, " \
      "falling back to CSR: #{error.message}"
    )
  end
end
