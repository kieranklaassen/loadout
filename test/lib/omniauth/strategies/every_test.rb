require "test_helper"

# Rack-level tests of the strategy on its own: the authorize URL, the state
# nonce cookie, state and transaction checks, and the auth hash built from the
# recorded token and UserInfo payloads. The app side is covered end to end in
# test/controllers/sessions/every_controller_test.rb.
class OmniAuth::Strategies::EveryTest < ActiveSupport::TestCase
  BASE = EveryOauthHelper::EVERY_BASE
  CALLBACK = "http://example.org/auth/every/callback"

  setup do
    @app = ->(env) { [ 200, {}, [ env["omniauth.auth"].to_json ] ] }
    @strategy = OmniAuth::Strategies::Every.new(@app, client_id: "client-id", client_secret: "client-secret", site: -> { BASE })
    @original_on_failure = OmniAuth.config.on_failure
    OmniAuth.config.on_failure = ->(env) { [ 401, {}, [ env["omniauth.error.type"].to_s ] ] }
  end

  teardown do
    OmniAuth.config.on_failure = @original_on_failure
  end

  test "the request phase redirects to Every's authorize URL with basic_profile and binds the state to a __Host- cookie" do
    session = {}
    status, headers, = start(session)

    assert_equal 302, status
    location = URI(headers["location"])
    params = Rack::Utils.parse_query(location.query)
    assert_equal "#{BASE}/oauth/authorize", "#{location.scheme}://#{location.host}#{location.path}"
    assert_equal "basic_profile", params["scope"]
    assert_equal "client-id", params["client_id"]
    assert_equal "code", params["response_type"]
    assert_equal CALLBACK, params["redirect_uri"]
    assert_nil params["code_challenge"]
    assert_equal session["omniauth.state"], params["state"]
    assert_kind_of Integer, session["omniauth.every"]["issued_at"]

    cookie = headers["set-cookie"]
    assert_match(/\A__Host-every_state=#{params["state"]};/, cookie)
    assert_match(/path=\//i, cookie)
    assert_match(/secure/i, cookie)
    assert_match(/httponly/i, cookie)
    assert_match(/samesite=lax/i, cookie)
  end

  test "a missing client configuration fails as every_oauth_unconfigured without redirecting" do
    unconfigured = OmniAuth::Strategies::Every.new(@app, client_id: nil, client_secret: nil, site: -> { nil })

    status, _, body = unconfigured.call(Rack::MockRequest.env_for("/auth/every", "rack.session" => {}))

    assert_equal 401, status
    assert_equal "every_oauth_unconfigured", body.join
  end

  test "the callback exchanges the code, reads UserInfo, and clears the transaction" do
    session = {}
    start(session)
    state = session["omniauth.state"]

    token = stub_request(:post, "#{BASE}/oauth/token")
      .with(body: hash_including("grant_type" => "authorization_code", "code" => "authorization-code",
                                 "client_id" => "client-id", "client_secret" => "client-secret", "redirect_uri" => CALLBACK))
      .to_return(status: 200, body: every_payload("token").to_json, headers: { "Content-Type" => "application/json" })
    userinfo = stub_every_userinfo(every_payload("userinfo", name: " Bo Every "))

    status, _, body = callback(session, "code=authorization-code&state=#{state}", cookie: "__Host-every_state=#{state}")

    assert_equal 200, status
    assert_requested token
    assert_requested userinfo
    auth = JSON.parse(body.join)
    assert_equal "4242", auth["uid"]
    assert_equal "bo@every.to", auth["info"]["email"]
    assert_equal "Bo Every", auth["info"]["name"]
    assert_equal "https://every.to/avatars/bo.png", auth["info"]["image"]
    assert_equal "all_access", auth["extra"]["raw_info"]["tier"]
    assert_nil session["omniauth.state"]
    assert_nil session["omniauth.every"]
  end

  test "the callback requires the __Host- state cookie to equal the state" do
    session = {}
    start(session)
    status, _, body = callback(session, "code=c&state=#{session["omniauth.state"]}")
    assert_equal [ 401, "csrf_detected" ], [ status, body.join ]

    session = {}
    start(session)
    status, _, body = callback(session, "code=c&state=#{session["omniauth.state"]}", cookie: "__Host-every_state=other")
    assert_equal [ 401, "csrf_detected" ], [ status, body.join ]
  end

  test "a state mismatch fails without consuming another tab's transaction" do
    session = {}
    start(session)
    stale_state = session["omniauth.state"]
    start(session)
    live_state = session["omniauth.state"]
    live_txn = session["omniauth.every"].dup

    status, _, body = callback(session, "code=c&state=#{stale_state}", cookie: "__Host-every_state=#{stale_state}")

    assert_equal [ 401, "csrf_detected" ], [ status, body.join ]
    assert_equal live_state, session["omniauth.state"]
    assert_equal live_txn, session["omniauth.every"]
  end

  test "a missing or expired transaction fails closed" do
    status, _, body = callback({}, "code=c&state=anything", cookie: "__Host-every_state=anything")
    assert_equal [ 401, "csrf_detected" ], [ status, body.join ]

    session = {}
    start(session)
    session["omniauth.every"]["issued_at"] = (OmniAuth::Strategies::Every::TRANSACTION_TTL + 5).seconds.ago.to_i
    state = session["omniauth.state"]
    status, _, body = callback(session, "code=c&state=#{state}", cookie: "__Host-every_state=#{state}")
    assert_equal [ 401, "csrf_detected" ], [ status, body.join ]
  end

  test "a provider error on a bound callback fails with that error" do
    session = {}
    start(session)
    state = session["omniauth.state"]

    status, _, body = callback(session, "error=access_denied&state=#{state}", cookie: "__Host-every_state=#{state}")

    assert_equal [ 401, "access_denied" ], [ status, body.join ]
  end

  test "a rejected code is invalid credentials" do
    session = {}
    start(session)
    state = session["omniauth.state"]
    stub_every_token(status: 400, payload: every_payload("token_invalid_grant"))

    status, _, body = callback(session, "code=c&state=#{state}", cookie: "__Host-every_state=#{state}")

    assert_equal [ 401, "invalid_credentials" ], [ status, body.join ]
  end

  test "userinfo without user_id or email is invalid credentials" do
    session = {}
    start(session)
    state = session["omniauth.state"]
    stub_every_token
    stub_every_userinfo(every_payload("userinfo").except("email"))

    status, _, body = callback(session, "code=c&state=#{state}", cookie: "__Host-every_state=#{state}")

    assert_equal [ 401, "invalid_credentials" ], [ status, body.join ]
  end

  test "an unreachable Every is a timeout" do
    session = {}
    start(session)
    state = session["omniauth.state"]
    stub_request(:post, "#{BASE}/oauth/token").to_timeout

    status, _, body = callback(session, "code=c&state=#{state}", cookie: "__Host-every_state=#{state}")

    assert_equal [ 401, "timeout" ], [ status, body.join ]
  end

  private

  def start(session)
    @strategy.call(Rack::MockRequest.env_for("/auth/every", "rack.session" => session))
  end

  def callback(session, query, cookie: nil)
    @strategy.call(Rack::MockRequest.env_for("/auth/every/callback?#{query}", "rack.session" => session, "HTTP_COOKIE" => cookie))
  end
end
