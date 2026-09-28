require "test_helper"

class AgentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    clear_oauth_rate_limits
    @user = users(:every_cy)
  end

  test "signed out, the agents page asks for sign-in" do
    get agents_path
    assert_redirected_to new_session_path
  end

  test "lists connected agents grouped by client with the MCP URL and setup snippets" do
    connect_agent(user: @user, client_name: "Cursor")
    connect_agent(user: @user, client_name: "Claude Code")
    client_id = OauthClient.find_by!(client_name: "Cursor").client_id
    verifier, challenge = pkce_pair
    exchange_code(code: approve(user: @user, client_id:, challenge:), client_id:, verifier:)
    connect_agent(user: users(:every_ana), client_name: "Codex")

    sign_in_as(@user)
    get agents_path

    assert_response :success
    assert_equal "agents/index", inertia.component
    assert_equal [ "Claude Code", "Cursor" ], inertia.props[:agents].map { |agent| agent[:name] }.sort
    assert_equal %i[connected_at id known_key last_used_at name open_suggestions redirect_host], inertia.props[:agents].first.keys.map(&:to_sym).sort
    assert_equal "http://www.example.com/mcp", inertia.props[:mcp_url]
    assert_match(/Ask me before you guess/, inertia.props[:suggested_prompt])
    assert_equal Agents::Capabilities.to_prop.deep_stringify_keys, inertia.props[:capabilities].deep_stringify_keys

    install = URI.parse(inertia.props[:cursor_install_url])
    assert_equal [ "cursor", "anysphere.cursor-deeplink", "/mcp/install" ], [ install.scheme, install.host, install.path ]
    query = Rack::Utils.parse_query(install.query)
    assert_equal "toolbox", query["name"]
    assert_equal({ "url" => "http://www.example.com/mcp" }, JSON.parse(Base64.strict_decode64(query["config"])))
  end

  test "a client is known only by where its sign-in code went: an https redirect on an allowlisted host" do
    claude_uri = "https://claude.ai/api/mcp/auth_callback"
    connect = lambda do |name, redirect_uris, redirect_uri|
      client_id = register_client(client_name: name, redirect_uris:)
      verifier, challenge = pkce_pair
      code = approve(user: @user, client_id:, challenge:, redirect_uri:)
      sign_out
      exchange_code(code:, client_id:, verifier:, redirect_uri:)
      client_id
    end
    connect.("Claude", [ claude_uri ], claude_uri)
    connect.("Cursor", [ "cursor://anysphere.cursor-retrieval/oauth/callback" ], "cursor://anysphere.cursor-retrieval/oauth/callback")
    connect.("Also Claude", [ McpOauthHelper::LOOPBACK_REDIRECT, claude_uri ], McpOauthHelper::LOOPBACK_REDIRECT)

    sign_in_as(@user)
    get agents_path

    agents = inertia.props[:agents].index_by { |agent| agent[:name] }
    assert_equal [ "claude", "claude.ai" ], agents["Claude"].values_at(:known_key, :redirect_host)
    assert_equal [ nil, "cursor://anysphere.cursor-retrieval" ], agents["Cursor"].values_at(:known_key, :redirect_host)
    assert_equal [ nil, "127.0.0.1" ], agents["Also Claude"].values_at(:known_key, :redirect_host), "registering an allowlisted URI is not using it"
  end

  test "each agent carries the count of open suggestions that revoking it would withdraw" do
    client_id, = connect_agent(user: @user, client_name: "Claude")
    client = OauthClient.find_by!(client_id:)
    Toolbox::Update.call(
      user: @user, operations: [ { op: "suggest", category: "video", tool: "runway" }, { op: "suggest", category: "video", tool: "Hedra" } ],
      source: "mcp", client_name: "Claude", oauth_client_id: client.id
    )
    Toolbox::Update.call(user: @user, operations: [ { op: "suggest", category: "coding", tool: "claude-code" } ], source: "webmcp")
    assert_equal 3, @user.pick_suggestions.open.count, "the WebMCP suggestion exists but is no client's"

    sign_in_as(@user)
    get agents_path

    assert_equal 2, inertia.props[:agents].sole[:open_suggestions]
  end

  test "revoking a client ends all of that member's grants for it on the next call (AE3)" do
    client_id, first = connect_agent(user: @user, client_name: "Cursor")
    verifier, challenge = pkce_pair
    second = exchange_code(code: approve(user: @user, client_id:, challenge:), client_id:, verifier:)
    _ana_client, ana_tokens = connect_agent(user: users(:every_ana), client_name: "Cursor")
    sign_out

    sign_in_as(@user)
    delete agent_path(client_id)
    assert_redirected_to agents_path
    assert_response :see_other
    assert_equal "Disconnected Cursor.", flash[:notice]

    [ first, second ].each do |tokens|
      mcp_request("tools/list", token: tokens["access_token"])
      assert_response :unauthorized
      refresh_tokens(refresh_token: tokens["refresh_token"], client_id:)
      assert_response :bad_request
    end
    mcp_request("tools/list", token: ana_tokens["access_token"])
    assert_response :success

    get agents_path
    assert_empty inertia.props[:agents]
  end

  test "revoking a client that is already disconnected says so" do
    client_id, = connect_agent(user: @user, client_name: "Cursor")
    sign_in_as(@user)
    delete agent_path(client_id)

    delete agent_path(client_id)

    assert_redirected_to agents_path
    assert_equal "Cursor was already disconnected.", flash[:notice]
  end

  test "revoking goes back to the page it was sent from, so Revoke in Settings stays in Settings" do
    client_id, = connect_agent(user: @user, client_name: "Cursor")
    sign_in_as(@user)

    delete agent_path(client_id), headers: { "HTTP_REFERER" => settings_url }

    assert_redirected_to settings_url
    assert_response :see_other
    assert_equal "Disconnected Cursor.", flash[:notice]
    assert_empty OauthGrant.active.where(user: @user)
  end

  test "revoking never redirects to another host, whatever the referer says" do
    client_id, = connect_agent(user: @user, client_name: "Cursor")
    sign_in_as(@user)

    delete agent_path(client_id), headers: { "HTTP_REFERER" => "https://evil.example/agents" }

    assert_redirected_to agents_path
  end

  test "revoking a client withdraws that client's open suggestions and no other client's (AE9)" do
    ids = 2.times.map { connect_agent(user: @user, client_name: "Claude").first }
    ours, theirs = ids.map { |client_id| OauthClient.find_by!(client_id:) }
    suggest = lambda do |tool, client|
      Toolbox::Update.call(
        user: @user, operations: [ { op: "suggest", category: "video", tool: } ], source: client ? "mcp" : "webmcp",
        client_name: client&.client_name, oauth_client_id: client&.id
      ).suggestions.sole
    end
    ours_open, theirs_open, webmcp_open = suggest.("runway", ours), suggest.("Hedra", theirs), suggest.("Veo", nil)

    sign_in_as(@user)
    delete agent_path(ids.first)

    assert_equal [ "withdrawn", "open", "open" ], [ ours_open, theirs_open, webmcp_open ].map { |suggestion| suggestion.reload.status }
  end

  test "reconnecting after a revoke goes through consent again" do
    client_id, = connect_agent(user: @user, client_name: "Cursor")
    sign_in_as(@user)
    delete agent_path(client_id)

    _verifier, challenge = pkce_pair
    get "/oauth/authorize", params: authorization_params(client_id:, challenge:)
    assert_equal "oauth/consent", inertia.component
  end
end
