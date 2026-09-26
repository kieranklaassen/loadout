# frozen_string_literal: true

# Riffrec feedback-capture configuration.
#
# The template ships this module WIRED IN but degrading to a no-op: it is
# `configured?` only when BOTH placeholder env vars are present, and it never
# exposes a server secret to the browser. No real credential or live endpoint
# appears anywhere in this repo (see .env.example — names only).
module Riffrec
  module_function

  # Capture is enabled only when both are set. Unset (test/CI/default) → no-op.
  def configured?
    ENV["RIFFREC_PUBLIC_KEY"].present? && ENV["RIFFREC_ENDPOINT"].present?
  end

  # The browser-safe config handed to the capture widget: the endpoint and the
  # publishable capture key ONLY. Never include a server secret here — this
  # travels to the client in the page props.
  def client_config
    return nil unless configured?

    {
      endpoint: ENV["RIFFREC_ENDPOINT"],
      public_key: ENV["RIFFREC_PUBLIC_KEY"]
    }
  end
end
