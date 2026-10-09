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

  test "the request phase redirects to Every's authorize URL with openid basic_profile and binds the state to a __Host- cookie" do
    session = {}
    status, headers, = start(session)

    assert_equal 302, status
    location = URI(headers["location"])
    params = Rack::Utils.parse_query(location.query)
    assert_equal "#{BASE}/oauth/authorize", "#{location.scheme}://#{location.host}#{location.path}"
    assert_equal "openid basic_profile", params["scope"]
    assert_nil params["prompt"], "an ordinary sign-in lets Every show its screens"
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

  test "prompt=none on the sign-in start asks Every for a silent answer" do
    _, headers, = start({}, query: "prompt=none")

    assert_equal "none", authorize_params(headers)["prompt"]
  end

  test "any other prompt value is not passed on" do
    _, headers, = start({}, query: "prompt=login")

    assert_nil authorize_params(headers)["prompt"]
  end

  test "without openid in the scope there is no silent sign-in, since Every ignores prompt then" do
    strategy = OmniAuth::Strategies::Every.new(@app, client_id: "client-id", client_secret: "client-secret", site: -> { BASE }, requested_scope: -> { "basic_profile" })

    _, headers, = strategy.call(Rack::MockRequest.env_for("/auth/every?prompt=none", "rack.session" => {}))

    params = authorize_params(headers)
    assert_equal "basic_profile", params["scope"]
    assert_nil params["prompt"]
    assert_not OmniAuth::Strategies::Every.silent_capable?("basic_profile")
    assert OmniAuth::Strategies::Every.silent_capable?("basic_profile openid")
  end

  test "a silent answer from Every on a bound callback fails with that error" do
    session = {}
    start(session, query: "prompt=none")
    state = session["omniauth.state"]

    status, _, body = callback(session, "error=login_required&state=#{state}", cookie: "__Host-every_state=#{state}")

    assert_equal [ 401, "login_required" ], [ status, body.join ]
    assert_nil session["omniauth.every"]
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

  # The framed attempt (Sessions::SilentController): its own state, its own
  # cookie, and nothing of the session.

  test "a framed callback with its own state cookie reads the identity and never fails over to the sign-in page" do
    stub_every_token
    stub_every_userinfo
    session = {}

    status, _, body = silent_callback(session, "code=authorization-code")

    assert_equal 200, status
    assert_equal({ "error" => nil }, @silent)
    assert_equal "4242", JSON.parse(body.join)["uid"]
    assert_empty session
  end

  test "a framed callback records Every's answer and asks for no token" do
    token = stub_every_token

    status, = silent_callback({}, "error=login_required")

    assert_equal 200, status
    assert_equal({ "error" => "login_required" }, @silent)
    assert_not_requested token
  end

  test "a framed callback without its state cookie is csrf_detected and asks for no token" do
    token = stub_every_token

    silent_callback({}, "code=c", cookie: nil)
    assert_equal({ "error" => "csrf_detected" }, @silent)

    silent_callback({}, "code=c", cookie: "__Host-every_silent_state=silent.other")
    assert_equal({ "error" => "csrf_detected" }, @silent)
    assert_not_requested token
  end

  test "a framed callback records a rejected code and an unreachable Every" do
    stub_every_token(status: 400, payload: every_payload("token_invalid_grant"))
    silent_callback({}, "code=c")
    assert_equal({ "error" => "invalid_credentials" }, @silent)

    stub_request(:post, "#{BASE}/oauth/token").to_timeout
    silent_callback({}, "code=c")
    assert_equal({ "error" => "timeout" }, @silent)
  end

  test "a framed callback records an error nobody named, and never reaches on_failure" do
    stub_every_token
    stub_request(:get, "#{BASE}/oauth/userinfo").to_return(status: 200, body: "<html>down</html>", headers: { "Content-Type" => "text/html" })

    status, = silent_callback({}, "code=c")

    assert_equal 200, status
    assert_equal({ "error" => "failed" }, @silent)
  end

  test "a framed callback leaves a clicked sign-in that is under way as it was, and the click still completes" do
    stub_every_token
    stub_every_userinfo
    session = {}
    start(session, query: "origin=%2Ftoolbox%2Fedit")
    state = session["omniauth.state"]
    before = session.deep_dup

    silent_callback(session, "error=login_required")
    assert_equal before, session
    silent_callback(session, "code=authorization-code")
    assert_equal before, session

    origin = nil
    @app = ->(env) { origin = env["omniauth.origin"]; [ 200, {}, [] ] }
    strategy = OmniAuth::Strategies::Every.new(@app, client_id: "client-id", client_secret: "client-secret", site: -> { BASE })
    status, = strategy.call(Rack::MockRequest.env_for("/auth/every/callback?code=authorization-code&state=#{state}",
      "rack.session" => session, "HTTP_COOKIE" => "__Host-every_state=#{state}"))

    assert_equal [ 200, "/toolbox/edit" ], [ status, origin ]
  end

  test "the calls to Every give up after a few seconds" do
    request = @strategy.client.connection.options

    assert_equal [ 5, 5 ], [ request.open_timeout, request.timeout ]
  end

  test "the framed attempt's authorize URL asks silently with the given state and nothing else" do
    url = OmniAuth::Strategies::Every.silent_authorize_url(site: BASE, client_id: "client-id", scope: "openid basic_profile",
      redirect_uri: CALLBACK, state: "silent.abc")

    assert url.start_with?("#{BASE}/oauth/authorize?")
    params = Rack::Utils.parse_query(URI(url).query)
    assert_equal({ "client_id" => "client-id", "prompt" => "none", "redirect_uri" => CALLBACK, "response_type" => "code",
                   "scope" => "openid basic_profile", "state" => "silent.abc" }, params)
  end

  private

  # A callback of the framed attempt: the state is its own, bound by its own cookie.
  def silent_callback(session, query, state: "silent.abc", cookie: "__Host-every_silent_state=silent.abc")
    @silent = nil
    app = ->(env) { @silent = env["every.silent"]; [ 200, {}, [ env["omniauth.auth"].to_json ] ] }
    strategy = OmniAuth::Strategies::Every.new(app, client_id: "client-id", client_secret: "client-secret", site: -> { BASE })
    strategy.call(Rack::MockRequest.env_for("/auth/every/callback?#{query}&state=#{state}", "rack.session" => session, "HTTP_COOKIE" => cookie))
  end

  def start(session, query: nil)
    @strategy.call(Rack::MockRequest.env_for([ "/auth/every", query ].compact.join("?"), "rack.session" => session))
  end

  def authorize_params(headers)
    Rack::Utils.parse_query(URI(headers["location"]).query)
  end

  def callback(session, query, cookie: nil)
    @strategy.call(Rack::MockRequest.env_for("/auth/every/callback?#{query}", "rack.session" => session, "HTTP_COOKIE" => cookie))
  end
end
