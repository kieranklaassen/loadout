require "test_helper"

class WellKnownControllerTest < ActionDispatch::IntegrationTest
  test "protected-resource metadata names the /mcp resource and this authorization server (RFC 9728)" do
    [ "/.well-known/oauth-protected-resource", "/.well-known/oauth-protected-resource/mcp" ].each do |path|
      get path

      assert_response :success
      assert_equal "http://www.example.com/mcp", response.parsed_body["resource"]
      assert_equal [ "http://www.example.com" ], response.parsed_body["authorization_servers"]
      assert_equal [ "header" ], response.parsed_body["bearer_methods_supported"]
    end
  end

  test "authorization-server metadata advertises the endpoints, PKCE S256, and public clients only (RFC 8414)" do
    get "/.well-known/oauth-authorization-server"

    assert_response :success
    metadata = response.parsed_body
    assert_equal "http://www.example.com", metadata["issuer"]
    assert_equal "http://www.example.com/oauth/authorize", metadata["authorization_endpoint"]
    assert_equal "http://www.example.com/oauth/token", metadata["token_endpoint"]
    assert_equal "http://www.example.com/oauth/register", metadata["registration_endpoint"]
    assert_equal "http://www.example.com/oauth/revoke", metadata["revocation_endpoint"]
    assert_equal [ "code" ], metadata["response_types_supported"]
    assert_equal %w[authorization_code refresh_token], metadata["grant_types_supported"]
    assert_equal [ "S256" ], metadata["code_challenge_methods_supported"]
    assert_equal [ "none" ], metadata["token_endpoint_auth_methods_supported"]
  end

  test "PUBLIC_BASE_URL wins over the request host" do
    Rails.application.config.x.public_base_url = "https://loadout.every.to"
    get "/.well-known/oauth-protected-resource"

    assert_equal "https://loadout.every.to/mcp", response.parsed_body["resource"]
  ensure
    Rails.application.config.x.public_base_url = nil
  end
end
