# frozen_string_literal: true

# Bounds the SSR render round-trip so a hung or slow SSR process can never stall
# a web request indefinitely. Inertia's SSRRenderer calls Net::HTTP.start without
# timeouts (lib/inertia_rails/ssr_renderer.rb); left unbounded, one wedged SSR
# worker ties up a Puma thread until the socket dies on its own.
#
# We inject open/read timeouts, but ONLY around the SSR HTTP call — a thread-local
# flag is raised for the duration of SSRRenderer#request and the prepended
# Net::HTTP.start reads it, so ordinary application HTTP is untouched.
#
# Carried verbatim from the two fleet apps that independently arrived at this same
# patch (thinkroom, kieranklaassen-com), so SSR is safe to enable later without
# rediscovering the footgun. Loads harmlessly whether or not SSR is enabled.

return unless defined?(InertiaRails::SSRRenderer)

module InertiaSSRTimeout
  TIMEOUT_SECONDS = Float(ENV.fetch("INERTIA_SSR_TIMEOUT", "2"))
  IN_PROGRESS_KEY = :inertia_ssr_http_in_progress

  # Flags the current thread while the SSR HTTP call runs.
  module SSRRendererPatch
    private

    def request
      Thread.current[IN_PROGRESS_KEY] = true
      super
    ensure
      Thread.current[IN_PROGRESS_KEY] = false
    end
  end

  # Injects timeouts into Net::HTTP.start only while an SSR request is in flight.
  module NetHTTPPatch
    def start(*args, **kwargs, &block)
      if Thread.current[InertiaSSRTimeout::IN_PROGRESS_KEY]
        kwargs[:open_timeout] ||= InertiaSSRTimeout::TIMEOUT_SECONDS
        kwargs[:read_timeout] ||= InertiaSSRTimeout::TIMEOUT_SECONDS
      end
      super
    end
  end
end

InertiaRails::SSRRenderer.prepend(InertiaSSRTimeout::SSRRendererPatch)
Net::HTTP.singleton_class.prepend(InertiaSSRTimeout::NetHTTPPatch)
