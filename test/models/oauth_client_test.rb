require "test_helper"

class OauthClientTest < ActiveSupport::TestCase
  def client(*uris) = OauthClient.create!(client_name: "Agent", redirect_uris: uris)

  test "a redirect URI must match a registered one exactly" do
    agent = client("https://claude.ai/api/mcp/auth_callback", "cursor://anysphere.cursor-retrieval/oauth/callback")

    assert agent.redirect_uri_registered?("https://claude.ai/api/mcp/auth_callback")
    assert agent.redirect_uri_registered?("cursor://anysphere.cursor-retrieval/oauth/callback")
    assert_not agent.redirect_uri_registered?("https://claude.ai/api/mcp/auth_callback/")
    assert_not agent.redirect_uri_registered?("https://claude.ai/api/mcp/auth_callback?x=1")
    assert_not agent.redirect_uri_registered?("https://claude.ai:8443/api/mcp/auth_callback")
    assert_not agent.redirect_uri_registered?(nil)
  end

  test "a loopback redirect may use any port, but nothing else may change (RFC 8252)" do
    agent = client("http://127.0.0.1:33418/callback", "http://localhost/cb")

    assert agent.redirect_uri_registered?("http://127.0.0.1:50123/callback")
    assert agent.redirect_uri_registered?("http://localhost:8080/cb")
    assert_not agent.redirect_uri_registered?("http://127.0.0.1:50123/other")
    assert_not agent.redirect_uri_registered?("http://localhost:8080/callback")
    assert_not agent.redirect_uri_registered?("http://127.0.0.1:50123/callback#x")
    assert_not agent.redirect_uri_registered?("https://127.0.0.1:50123/callback")
  end

  test "client ids are random and unique" do
    assert_not_equal client("https://a.example/cb").client_id, client("https://a.example/cb").client_id
  end

  test "client names lose control and format characters, so one name cannot pose as another" do
    spoofed = "Cla\u200Dude \u202Edoce\u202C\u2066\uFEFF\u00AD Code\t\u0007"
    agent = OauthClient.create!(client_name: spoofed, redirect_uris: [ "https://a.example/cb" ])

    assert_equal "Claude doce Code", agent.client_name
    assert_equal "Claude Code", OauthClient.create!(client_name: "  Claude \u200B Code ", redirect_uris: [ "https://a.example/cb" ]).client_name
  end
end
