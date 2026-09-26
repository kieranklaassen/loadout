# Stubs Every's token and UserInfo endpoints with the recorded payloads in
# test/fixtures/files/every_oauth/, shaped from Every's Oauth::UserInfoController
# and its SSO guide (apps/api/plans/api/oauth_sso.md). The client configuration
# is set per test and restored afterwards; no live keys.
module EveryOauthHelper
  EVERY_BASE = "https://every.test"

  def configure_every_oauth
    every = Rails.application.config.x.every_oauth
    @every_oauth_originals = { client_id: every.client_id, client_secret: every.client_secret, base_url: every.base_url }
    every.client_id = "client-id"
    every.client_secret = "client-secret"
    every.base_url = EVERY_BASE
  end

  def restore_every_oauth
    return unless @every_oauth_originals

    every = Rails.application.config.x.every_oauth
    @every_oauth_originals.each { |key, value| every[key] = value }
  end

  def every_payload(name, **overrides)
    JSON.parse(file_fixture("every_oauth/#{name}.json").read).merge(overrides.stringify_keys)
  end

  def stub_every_token(status: 200, payload: every_payload("token"))
    stub_request(:post, "#{EVERY_BASE}/oauth/token")
      .to_return(status: status, body: payload.to_json, headers: { "Content-Type" => "application/json" })
  end

  def stub_every_userinfo(payload = every_payload("userinfo"))
    stub_request(:get, "#{EVERY_BASE}/oauth/userinfo")
      .with(headers: { "Authorization" => "Bearer access-token" })
      .to_return(status: 200, body: payload.to_json, headers: { "Content-Type" => "application/json" })
  end
end

ActiveSupport.on_load(:active_support_test_case) { include EveryOauthHelper }
