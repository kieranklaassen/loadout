require "test_helper"

class Oauth::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  setup { clear_oauth_rate_limits }

  def register(body)
    post "/oauth/register", params: body.is_a?(String) ? body : body.to_json, headers: { "Content-Type" => "application/json" }
  end

  test "registers a public client and answers with its client_id (RFC 7591)" do
    uris = [ "http://127.0.0.1:33418/callback", "http://localhost/cb", "http://[::1]:9000/cb", "https://claude.ai/api/mcp/auth_callback", "cursor://anysphere.cursor-retrieval/oauth/callback" ]

    assert_difference -> { OauthClient.count } => 1 do
      register(client_name: "Cursor", redirect_uris: uris, token_endpoint_auth_method: "none", grant_types: %w[authorization_code refresh_token], software_id: "cursor")
    end

    assert_response :created
    body = response.parsed_body
    assert body["client_id"].present?
    assert_nil body["client_secret"]
    assert_equal [ "none", uris, "Cursor" ], body.values_at("token_endpoint_auth_method", "redirect_uris", "client_name")
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal "cursor", OauthClient.find_by!(client_id: body["client_id"]).software_id
  end

  test "a client without a name is still registered, as an unnamed agent" do
    register(redirect_uris: [ "https://example.com/cb" ])

    assert_response :created
    assert_equal "Unnamed agent", response.parsed_body["client_name"]
  end

  test "rejects redirect URIs that are not https, loopback http, or a private-use scheme" do
    [ "javascript:alert(1)", "data:text/html,hi", "file:///etc/passwd", "http://evil.example/cb",
      "https://example.com/cb#frag", "/relative", "https://user:pw@example.com/cb", "vbscript:x" ].each do |uri|
      assert_no_difference -> { OauthClient.count } do
        register(client_name: "Bad", redirect_uris: [ uri ])
      end
      assert_response :bad_request
      assert_equal "invalid_redirect_uri", response.parsed_body["error"], uri
    end
  end

  test "rejects malformed and unsupported metadata" do
    register("not json")
    assert_equal "invalid_client_metadata", response.parsed_body["error"]

    register(client_name: "No URIs")
    assert_equal "invalid_client_metadata", response.parsed_body["error"]

    register(redirect_uris: [])
    assert_equal "invalid_redirect_uri", response.parsed_body["error"]

    register(redirect_uris: [ "https://example.com/cb" ], token_endpoint_auth_method: "client_secret_basic")
    assert_equal "invalid_client_metadata", response.parsed_body["error"]

    register(redirect_uris: [ "https://example.com/cb" ], grant_types: [ "client_credentials" ])
    assert_equal "invalid_client_metadata", response.parsed_body["error"]

    register(redirect_uris: [ "https://example.com/cb" ], client_name: { html: true })
    assert_response :bad_request
    assert_equal 0, OauthClient.count
  end

  test "registration works without a CSRF token and is rate limited" do
    ActionController::Base.allow_forgery_protection = true
    20.times { register(redirect_uris: [ "https://example.com/cb" ]) }
    assert_response :created

    register(redirect_uris: [ "https://example.com/cb" ])
    assert_response :too_many_requests
  ensure
    ActionController::Base.allow_forgery_protection = false
  end
end
