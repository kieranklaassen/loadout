# frozen_string_literal: true

# WebMCP (docs/modules/webmcp.md): Chrome origin-trial tokens.
#
# Chrome exposes the page model context without a flag only on origins
# registered for the WebMCP origin trial. Tokens are public by design — Google
# signs each one for a single origin — so the layout emits them as <meta> tags.
# WEBMCP_ORIGIN_TRIAL_TOKEN holds one token per production host (whitespace- or
# comma-separated); Chrome ignores the ones bound to another origin. Anything
# outside the base64 alphabet is dropped rather than interpolated into markup.
module Webmcp
  ORIGIN_TRIAL_ENV = "WEBMCP_ORIGIN_TRIAL_TOKEN"
  TOKEN_FORMAT = /\A[A-Za-z0-9+\/=]+\z/

  module_function

  def origin_trial_tokens(env = ENV)
    env[ORIGIN_TRIAL_ENV].to_s.split(/[\s,]+/).grep(TOKEN_FORMAT)
  end
end
