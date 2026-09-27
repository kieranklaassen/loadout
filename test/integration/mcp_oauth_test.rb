require "test_helper"

class McpOauthTest < ActionDispatch::IntegrationTest
  setup do
    clear_oauth_rate_limits
    @user = users(:every_cy)
  end

  test "the full PKCE dance ends in MCP initialize, tools/list, and a suggest_picks that names the client by id (F2)" do
    client_id, tokens = connect_agent(user: @user, client_name: "Claude Code")

    assert_equal [ "Bearer", 3600, "loadout" ], tokens.values_at("token_type", "expires_in", "scope")
    assert tokens["refresh_token"].present?
    assert_equal "no-store", response.headers["Cache-Control"]

    initialize = mcp_request("initialize", { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "claude-code", version: "1" } }, token: tokens["access_token"])
    assert_response :success
    assert_equal "loadout", initialize.dig("result", "serverInfo", "name")
    assert_match(/Ask the member before you guess/, initialize.dig("result", "instructions"))

    names = mcp_request("tools/list", token: tokens["access_token"]).dig("result", "tools").map { |tool| tool["name"] }
    assert_equal %w[list_categories search_catalog get_my_loadout get_team_rankings get_recent_changes suggest_picks], names

    entries_before = @user.entries.count
    result = mcp_request("tools/call", { name: "suggest_picks", arguments: { operations: [ { op: "suggest", category: "video", tool: "runway", rank: 1 } ] } }, token: tokens["access_token"])["result"]
    assert_equal false, result["isError"], result.dig("content", 0, "text")
    assert_match(/until the member confirms it/, JSON.parse(result.dig("content", 0, "text"))["message"])

    suggestion = @user.pick_suggestions.open.sole
    assert_equal [ OauthClient.find_by!(client_id:).id, "Claude Code", "runway" ], [ suggestion.oauth_client_id, suggestion.client_name, suggestion.tool.slug ]
    assert_equal entries_before, @user.entries.count
    assert_equal [ [ "suggested", "mcp", "Claude Code" ] ], @user.entry_changes.where(action: "suggested").pluck(:action, :source, :client_name)
    assert_not_nil @user.oauth_grants.sole.last_used_at
  end

  test "a decision that is the member's is refused over MCP, and read tools answer as the member" do
    _client_id, tokens = connect_agent(user: @user, client_name: "Claude Code")

    refused = mcp_request("tools/call", { name: "suggest_picks", arguments: { operations: [ { op: "confirm", suggestion_id: 1 } ] } }, token: tokens["access_token"])["result"]
    assert_equal true, refused["isError"]

    mine = JSON.parse(mcp_request("tools/call", { name: "get_my_loadout", arguments: {} }, token: tokens["access_token"]).dig("result", "content", 0, "text"))
    assert_equal [ "cy", "only_me" ], mine.values_at("handle", "visibility")

    team = JSON.parse(mcp_request("tools/call", { name: "get_team_rankings", arguments: {} }, token: tokens["access_token"]).dig("result", "content", 0, "text"))
    assert_equal "team", team["audience"]
  end

  test "codes and tokens are stored only as digests" do
    client_id, tokens = connect_agent(user: @user)

    grant = OauthGrant.sole
    assert_equal OauthToken.digest(tokens["access_token"]), grant.access_digest
    assert_equal OauthToken.digest(tokens["refresh_token"]), grant.refresh_digest
    stored = [ OauthGrant, OauthAuthorizationCode, OauthClient ].flat_map { |model| model.all.flat_map { |record| record.attributes.values } }.map(&:to_s)
    assert_not stored.any? { |value| value.include?(tokens["access_token"]) || value.include?(tokens["refresh_token"]) }
    assert_equal client_id, grant.oauth_client.client_id
  end

  test "a signed-out member is sent to sign in and comes back to the consent screen" do
    client_id = register_client
    _verifier, challenge = pkce_pair
    query = authorization_params(client_id:, challenge:)

    get "/oauth/authorize", params: query
    assert_redirected_to new_session_path

    configure_every_oauth
    https!
    stub_every_token
    stub_every_userinfo(every_payload("userinfo", user_id: @user.every_user_id, email: @user.email_address, name: @user.name))
    get "/auth/every"
    get "/auth/every/callback", params: { code: "authorization-code", state: Rack::Utils.parse_query(URI(response.location).query).fetch("state") }

    assert_equal "/oauth/authorize", URI(response.location).path
    assert_equal query.transform_keys(&:to_s), Rack::Utils.parse_query(URI(response.location).query)

    follow_redirect!
    assert_response :success
    assert_equal "oauth/consent", inertia.component
    assert_equal "Claude Code", inertia.props.dig(:client, :name)
    assert_equal "127.0.0.1", inertia.props[:redirect_host]
    assert_equal Agents::Capabilities.to_prop.deep_stringify_keys, inertia.props[:capabilities].deep_stringify_keys
    assert_equal "DENY", response.headers["X-Frame-Options"]
  ensure
    restore_every_oauth
  end

  test "consent gives an initial and the redirect host to any client but an https redirect on a known host (KTD18)" do
    _verifier, challenge = pkce_pair
    sign_in_as(@user)
    cases = {
      "https://example.org/cb" => [ "example.org", nil, false ],
      McpOauthHelper::LOOPBACK_REDIRECT => [ "127.0.0.1", nil, false ],
      "x-evil://claude.ai/cb" => [ "x-evil://claude.ai", nil, false ],
      "cursor://anysphere.cursor-retrieval/oauth" => [ "cursor://anysphere.cursor-retrieval", nil, false ],
      "https://claude.ai.evil.example/cb" => [ "claude.ai.evil.example", nil, false ],
      "https://claude.ai/api/mcp/auth_callback" => [ "claude.ai", "claude", true ],
      "https://CLAUDE.com/cb" => [ "CLAUDE.com", "claude", true ]
    }

    cases.each do |redirect_uri, (host, mark, known)|
      client_id = register_client(client_name: "Claude", redirect_uris: [ redirect_uri ])
      get "/oauth/authorize", params: authorization_params(client_id:, challenge:, redirect_uri:)

      assert_response :success, redirect_uri
      client = inertia.props[:client]
      assert_equal [ "Claude", host, mark, known ], [ client[:name], client[:redirect_host], client[:mark], client[:known] ], redirect_uri
      assert_equal host, inertia.props[:redirect_host], redirect_uri
    end
  end

  test "a client that registered a known host but sends the member to loopback is not known" do
    client_id = register_client(client_name: "Claude", redirect_uris: [ McpOauthHelper::LOOPBACK_REDIRECT, "https://claude.ai/api/mcp/auth_callback" ])
    _verifier, challenge = pkce_pair
    sign_in_as(@user)

    get "/oauth/authorize", params: authorization_params(client_id:, challenge:)

    assert_equal [ "127.0.0.1", nil, false ], inertia.props[:client].values_at(:redirect_host, :mark, :known)
  end

  test "approving redirects with the code, the state, and the issuer; denying says access_denied" do
    client_id = register_client
    _verifier, challenge = pkce_pair
    sign_in_as(@user)
    query = authorization_params(client_id:, challenge:, redirect_uri: "http://127.0.0.1:50999/callback")

    post "/oauth/authorize", params: query.merge(decision: "approve")
    assert response.location.start_with?("http://127.0.0.1:50999/callback?")
    returned = redirect_query(response.location)
    assert returned["code"].start_with?("lo_ac_")
    assert_equal [ "state-123", "http://www.example.com" ], returned.values_at("state", "iss")

    assert_no_difference -> { OauthAuthorizationCode.count } do
      post "/oauth/authorize", params: query.merge(decision: "deny")
    end
    assert_equal({ "error" => "access_denied", "state" => "state-123" }, redirect_query(response.location).slice("error", "state"))
  end

  test "an unregistered client or redirect URI is shown an error and never redirected" do
    client_id = register_client
    _verifier, challenge = pkce_pair
    sign_in_as(@user)

    get "/oauth/authorize", params: authorization_params(client_id: "nope", challenge:)
    assert_response :bad_request
    assert_equal "oauth/error", inertia.component

    get "/oauth/authorize", params: authorization_params(client_id:, challenge:, redirect_uri: "https://evil.example/cb")
    assert_response :bad_request
    assert_equal "oauth/error", inertia.component

    post "/oauth/authorize", params: authorization_params(client_id:, challenge:, redirect_uri: "https://evil.example/cb").merge(decision: "approve")
    assert_response :bad_request
    assert_equal 0, OauthAuthorizationCode.count
  end

  test "malformed authorization requests show an error page instead of redirecting (no open redirect)" do
    client_id = register_client
    _verifier, challenge = pkce_pair
    sign_in_as(@user)

    { { code_challenge: nil } => "invalid_request", { code_challenge_method: "plain" } => "invalid_request",
      { code_challenge: "short" } => "invalid_request", { response_type: "token" } => "unsupported_response_type" }.each do |override, error|
      get "/oauth/authorize", params: authorization_params(client_id:, challenge:).merge(override).compact
      assert_response :bad_request, override.inspect
      assert_inertia_component "oauth/error"
      assert_includes inertia.props[:message], error
    end
  end

  test "a resource other than this server's /mcp is rejected at authorize and at the token endpoint" do
    client_id = register_client
    verifier, challenge = pkce_pair
    sign_in_as(@user)

    get "/oauth/authorize", params: authorization_params(client_id:, challenge:, resource: "https://other.example/mcp")
    assert_response :bad_request
    assert_includes inertia.props[:message], "invalid_target"

    code = approve(user: @user, client_id:, challenge:, resource: "HTTP://WWW.EXAMPLE.COM/mcp/")
    body = exchange_code(code:, client_id:, verifier:, resource: "https://other.example/mcp")
    assert_response :bad_request
    assert_equal "invalid_target", body["error"]
  end

  test "an authorization request without a resource is bound to /mcp" do
    client_id = register_client
    verifier, challenge = pkce_pair
    code = approve(user: @user, client_id:, challenge:, resource: nil)

    tokens = exchange_code(code:, client_id:, verifier:, resource: nil)
    assert_response :success
    assert_equal "http://www.example.com/mcp", OauthGrant.sole.resource
    mcp_request("tools/list", token: tokens["access_token"])
    assert_response :success
  end

  test "a wrong PKCE verifier fails and burns the code" do
    client_id = register_client
    verifier, challenge = pkce_pair
    code = approve(user: @user, client_id:, challenge:)

    body = exchange_code(code:, client_id:, verifier: SecureRandom.urlsafe_base64(48))
    assert_response :bad_request
    assert_equal "invalid_grant", body["error"]

    exchange_code(code:, client_id:, verifier:)
    assert_response :bad_request
    assert_equal 0, OauthGrant.count
  end

  test "a code works once; replaying it fails and revokes the grant it issued" do
    client_id = register_client
    verifier, challenge = pkce_pair
    code = approve(user: @user, client_id:, challenge:)
    tokens = exchange_code(code:, client_id:, verifier:)
    assert_response :success

    body = exchange_code(code:, client_id:, verifier:)
    assert_response :bad_request
    assert_equal "invalid_grant", body["error"]
    assert OauthGrant.sole.revoked_at

    mcp_request("tools/list", token: tokens["access_token"])
    assert_response :unauthorized
  end

  test "a code is bound to its client, its redirect URI, and a 60 second lifetime" do
    client_id = register_client
    other_client_id = register_client(client_name: "Other")
    verifier, challenge = pkce_pair

    code = approve(user: @user, client_id:, challenge:)
    assert_equal "invalid_grant", exchange_code(code:, client_id: other_client_id, verifier:)["error"]

    code = approve(user: @user, client_id:, challenge:)
    assert_equal "invalid_grant", exchange_code(code:, client_id:, verifier:, redirect_uri: "http://127.0.0.1:1/callback")["error"]

    code = approve(user: @user, client_id:, challenge:)
    travel 61.seconds
    assert_equal "invalid_grant", exchange_code(code:, client_id:, verifier:)["error"]

    assert_equal "invalid_client", exchange_code(code:, client_id: "unknown", verifier:)["error"]
    assert_response :unauthorized
    assert_equal 0, OauthGrant.count
  end

  test "/mcp without a token answers 401 with resource_metadata and no error code" do
    mcp_request("tools/list", token: nil)

    assert_response :unauthorized
    assert_equal 'Bearer resource_metadata="http://www.example.com/.well-known/oauth-protected-resource"', response.headers["WWW-Authenticate"]
  end

  test "an unknown or expired access token answers 401 invalid_token" do
    mcp_request("tools/list", token: "lo_at_made-up")
    assert_response :unauthorized
    assert_match(/resource_metadata=".+", error="invalid_token"/, response.headers["WWW-Authenticate"])

    _client_id, tokens = connect_agent(user: @user)
    travel 61.minutes
    mcp_request("tools/list", token: tokens["access_token"])
    assert_response :unauthorized
    assert_match(/error="invalid_token"/, response.headers["WWW-Authenticate"])
  end

  test "a token issued for another resource is not accepted at /mcp" do
    _client_id, tokens = connect_agent(user: @user)
    OauthGrant.sole.update!(resource: "https://other.example/mcp")

    mcp_request("tools/list", token: tokens["access_token"])
    assert_response :unauthorized
  end

  test "refresh rotates both tokens, and presenting an old refresh token revokes the grant" do
    client_id, first = connect_agent(user: @user)

    travel 2.hours
    second = refresh_tokens(refresh_token: first["refresh_token"], client_id:)
    assert_response :success
    assert_not_equal first.values_at("access_token", "refresh_token"), second.values_at("access_token", "refresh_token")
    assert_equal "no-store", response.headers["Cache-Control"]

    mcp_request("tools/list", token: second["access_token"])
    assert_response :success
    mcp_request("tools/list", token: first["access_token"])
    assert_response :unauthorized

    reused = refresh_tokens(refresh_token: first["refresh_token"], client_id:)
    assert_response :bad_request
    assert_equal "invalid_grant", reused["error"]
    assert OauthGrant.sole.revoked_at

    mcp_request("tools/list", token: second["access_token"])
    assert_response :unauthorized
    refresh_tokens(refresh_token: second["refresh_token"], client_id:)
    assert_response :bad_request
  end

  test "a refresh token only works for its own client and until it expires" do
    client_id, tokens = connect_agent(user: @user)
    other_client_id = register_client(client_name: "Other")

    assert_equal "invalid_grant", refresh_tokens(refresh_token: tokens["refresh_token"], client_id: other_client_id)["error"]

    travel 31.days
    assert_equal "invalid_grant", refresh_tokens(refresh_token: tokens["refresh_token"], client_id:)["error"]
  end

  test "revoking through /oauth/revoke ends the grant on the next call (RFC 7009)" do
    client_id, tokens = connect_agent(user: @user)

    post "/oauth/revoke", params: { token: tokens["refresh_token"], token_type_hint: "refresh_token", client_id: }
    assert_response :ok

    mcp_request("tools/list", token: tokens["access_token"])
    assert_response :unauthorized

    post "/oauth/revoke", params: { token: "unknown", client_id: }
    assert_response :ok
  end

  test "another client cannot revoke a token it does not own" do
    _client_id, tokens = connect_agent(user: @user)
    other_client_id = register_client(client_name: "Other")

    post "/oauth/revoke", params: { token: tokens["access_token"], client_id: other_client_id }
    assert_response :ok
    assert_nil OauthGrant.sole.revoked_at
  end

  test "the token and MCP endpoints are rate limited" do
    60.times { post "/oauth/token", params: { grant_type: "refresh_token", client_id: "x" } }
    post "/oauth/token", params: { grant_type: "refresh_token", client_id: "x" }
    assert_response :too_many_requests

    300.times { |n| mcp_request("tools/list", token: "lo_at_random_#{n}") }
    mcp_request("tools/list", token: "lo_at_fresh")
    assert_response :too_many_requests, "a fresh token per request must not buy a fresh bucket"
  end

  class ConsentCsrfTest < ActionDispatch::IntegrationTest
    setup do
      clear_oauth_rate_limits
      ActionController::Base.allow_forgery_protection = true
    end

    teardown { ActionController::Base.allow_forgery_protection = false }

    test "the consent POST requires the form's authenticity token; the token endpoint does not" do
      client_id = register_client
      verifier, challenge = pkce_pair
      sign_in_as(users(:every_cy))
      query = authorization_params(client_id:, challenge:)

      post "/oauth/authorize", params: query.merge(decision: "approve")
      assert_response :unprocessable_content
      assert_equal 0, OauthAuthorizationCode.count

      get "/oauth/authorize", params: query
      post "/oauth/authorize", params: query.merge(decision: "approve", authenticity_token: inertia.props[:authenticity_token])
      assert_response :found

      exchange_code(code: redirect_query(response.location)["code"], client_id:, verifier:)
      assert_response :success
    end
  end
end
