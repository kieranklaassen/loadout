# Drives the MCP OAuth 2.1 flow the way an MCP client does: register, open the
# authorization URL, approve as the member, exchange the code with the PKCE
# verifier, then call /mcp with the bearer token.
module McpOauthHelper
  LOOPBACK_REDIRECT = "http://127.0.0.1:33418/callback".freeze

  def base_url = "http://www.example.com"
  def mcp_resource = "#{base_url}/mcp"

  def clear_oauth_rate_limits
    [ McpController, Oauth::RegistrationsController, Oauth::TokensController, Oauth::RevocationsController ].each do |controller|
      controller::RATE_LIMIT_STORE.clear
    end
  end

  def register_client(client_name: "Claude Code", redirect_uris: [ LOOPBACK_REDIRECT ], **metadata)
    post "/oauth/register", params: { client_name:, redirect_uris:, **metadata }.to_json,
      headers: { "Content-Type" => "application/json" }
    assert_response :created, response.body
    response.parsed_body["client_id"]
  end

  def pkce_pair
    verifier = SecureRandom.urlsafe_base64(48)
    [ verifier, Base64.urlsafe_encode64(OpenSSL::Digest::SHA256.digest(verifier), padding: false) ]
  end

  def authorization_params(client_id:, challenge:, redirect_uri: LOOPBACK_REDIRECT, **overrides)
    {
      response_type: "code", client_id:, redirect_uri:, code_challenge: challenge,
      code_challenge_method: "S256", state: "state-123", resource: mcp_resource, scope: "loadout"
    }.merge(overrides).compact
  end

  # Signs in, approves on the consent page, and returns the code from the redirect.
  def approve(user:, client_id:, challenge:, **overrides)
    sign_in_as(user)
    query = authorization_params(client_id:, challenge:, **overrides)
    get "/oauth/authorize", params: query
    assert_response :success
    assert_equal "oauth/consent", inertia.component

    post "/oauth/authorize", params: query.merge(decision: "approve")
    assert_response :found
    redirect_query(response.location).fetch("code")
  end

  def redirect_query(location)
    Rack::Utils.parse_query(URI.parse(location).query)
  end

  def exchange_code(code:, client_id:, verifier:, redirect_uri: LOOPBACK_REDIRECT, **extra)
    post "/oauth/token", params: {
      grant_type: "authorization_code", code:, client_id:, code_verifier: verifier, redirect_uri:, resource: mcp_resource
    }.merge(extra).compact
    response.parsed_body
  end

  def refresh_tokens(refresh_token:, client_id:)
    post "/oauth/token", params: { grant_type: "refresh_token", refresh_token:, client_id:, resource: mcp_resource }
    response.parsed_body
  end

  # Registers, approves, and exchanges: returns [client_id, token response].
  def connect_agent(user:, client_name: "Claude Code")
    client_id = register_client(client_name:)
    verifier, challenge = pkce_pair
    code = approve(user:, client_id:, challenge:)
    sign_out
    tokens = exchange_code(code:, client_id:, verifier:)
    assert_response :success, tokens.inspect
    [ client_id, tokens ]
  end

  def mcp_request(method, params = nil, token:, id: 1)
    body = { jsonrpc: "2.0", id:, method:, params: }.compact
    headers = { "Content-Type" => "application/json", "Accept" => "application/json, text/event-stream" }
    headers["Authorization"] = "Bearer #{token}" if token
    post "/mcp", params: body.to_json, headers: headers
    response.parsed_body
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) { include McpOauthHelper }
