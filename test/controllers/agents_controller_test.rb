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
    assert_equal "http://www.example.com/mcp", inertia.props[:mcp_url]
    assert_match(/Ask me before you guess/, inertia.props[:suggested_prompt])

    install = URI.parse(inertia.props[:cursor_install_url])
    assert_equal [ "cursor", "anysphere.cursor-deeplink", "/mcp/install" ], [ install.scheme, install.host, install.path ]
    query = Rack::Utils.parse_query(install.query)
    assert_equal "loadout", query["name"]
    assert_equal({ "url" => "http://www.example.com/mcp" }, JSON.parse(Base64.strict_decode64(query["config"])))
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

  test "reconnecting after a revoke goes through consent again" do
    client_id, = connect_agent(user: @user, client_name: "Cursor")
    sign_in_as(@user)
    delete agent_path(client_id)

    _verifier, challenge = pkce_pair
    get "/oauth/authorize", params: authorization_params(client_id:, challenge:)
    assert_equal "oauth/consent", inertia.component
  end
end
