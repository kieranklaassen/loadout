# frozen_string_literal: true

require "omniauth/strategies/every"

# Sign in with Every. All values are optional so a key-less checkout boots;
# without a client the sign-in start fails as every_oauth_unconfigured.
Rails.application.config.x.every_oauth.client_id = ENV["EVERY_OAUTH_CLIENT_ID"].presence
Rails.application.config.x.every_oauth.client_secret = ENV["EVERY_OAUTH_CLIENT_SECRET"].presence
Rails.application.config.x.every_oauth.base_url = ENV["EVERY_OAUTH_BASE_URL"].presence
Rails.application.config.x.public_base_url = ENV["PUBLIC_BASE_URL"].presence&.chomp("/")

# GET is allowed on /auth/every because the "Sign in with Every" link is a
# top-level navigation. The request phase carries no credential; the callback
# is bound to this browser through the state in the encrypted session plus the
# __Host- nonce cookie, which is the control against login CSRF.
OmniAuth.config.allowed_request_methods = %i[get]
OmniAuth.config.silence_get_warning = true
OmniAuth.config.logger = Rails.logger

# The redirect_uri registered with Every is built from PUBLIC_BASE_URL when it
# is set, so a proxy's internal host never leaks into it.
OmniAuth.config.full_host = lambda do |env|
  Rails.application.config.x.public_base_url || Rack::Request.new(env).base_url
end

OmniAuth.config.on_failure = ->(env) { Sessions::EveryController.action(:failure).call(env) }

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :every,
    client_id: -> { Rails.application.config.x.every_oauth.client_id },
    client_secret: -> { Rails.application.config.x.every_oauth.client_secret },
    site: -> { Rails.application.config.x.every_oauth.base_url }
end
