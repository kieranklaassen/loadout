require "test_helper"

# The framed attempt, driven through the real OmniAuth middleware: a hidden
# frame on any page asks Every whether this browser is signed in there, and
# every outcome ends on one tiny page the parent reads.
# https! because the __Host- state cookies are Secure.
class Sessions::SilentControllerTest < ActionDispatch::IntegrationTest
  FRAME = { "Sec-Fetch-Dest" => "iframe" }.freeze

  setup do
    configure_every_oauth
    https!
  end

  teardown { restore_every_oauth }

  # Whether an attempt is due

  test "a signed-out page says a silent attempt is due, and neither redirects nor sets a cookie to say so" do
    { root_path => 200, kind_path("coding") => 200, profile_path("ana") => 200, new_session_path(silent: "tried") => 200 }.each do |path, status|
      get path

      assert_response status, path
      assert_equal "/session/silent", inertia.props[:silent_sign_in_path], path
      assert_nil response.headers["Location"], path
      assert_nil response.headers["Set-Cookie"], path
    end
  end

  # The not-found page keeps the address to return to after sign-in in the
  # Rails session, as it did before, so that one cookie is its own.
  test "the not-found page says so too, and sets no cookie but the session it always set" do
    get "/nope"

    assert_response :not_found
    assert_equal "/session/silent", inertia.props[:silent_sign_in_path]
    assert_nil response.headers["Location"]
    assert_equal [ "_toolbox_session" ], Array(response.headers["Set-Cookie"]).flat_map { |line| line.split("\n") }.map { |cookie| cookie[/\A[^=]+/] }
  end

  test "no attempt is due when signed in, signed out on purpose, already tried, or without openid" do
    cookies[EverySilentSignIn::TRIED_COOKIE] = "asking"
    get root_path
    assert_nil inertia.props[:silent_sign_in_path]
    cookies.delete(EverySilentSignIn::TRIED_COOKIE)

    cookies[EverySilentSignIn::SIGNED_OUT_COOKIE] = "1"
    get root_path
    assert_nil inertia.props[:silent_sign_in_path]
    cookies.delete(EverySilentSignIn::SIGNED_OUT_COOKIE)

    Rails.application.config.x.every_oauth.scope = "basic_profile"
    get root_path
    assert_nil inertia.props[:silent_sign_in_path]
    Rails.application.config.x.every_oauth.scope = "openid basic_profile"

    sign_in_as(users(:every_ana))
    get root_path
    assert_nil inertia.props[:silent_sign_in_path]
  end

  # The start

  test "the frame is sent to Every with prompt=none, its own state and nothing else" do
    start_silent_attempt

    assert_response :redirect
    location = URI(response.location)
    params = Rack::Utils.parse_query(location.query)
    assert_equal "#{EveryOauthHelper::EVERY_BASE}/oauth/authorize", "#{location.scheme}://#{location.host}#{location.path}"
    assert_equal [ "none", "openid basic_profile", "https://www.example.com/auth/every/callback" ], params.values_at("prompt", "scope", "redirect_uri")
    assert params["state"].start_with?("silent.")
    assert_equal params["state"], cookies[OmniAuth::Strategies::Every::SILENT_STATE_COOKIE]
    assert_equal %w[client_id prompt redirect_uri response_type scope state], params.keys.sort
    assert_no_match(/_session=/, response.headers["Set-Cookie"].to_s)
  end

  test "a browser that sends no Sec-Fetch-Dest is sent on too, and so is a frame a service worker passed on" do
    cookies["every_silent_tried"] = "asking"
    get "/session/silent"
    assert_response :redirect

    get "/session/silent", headers: { "Sec-Fetch-Dest" => "empty" }
    assert_response :redirect
  end

  test "the start refuses, with no redirect, anything but a frame of a browser that keeps cookies and may be asked" do
    get "/session/silent", headers: FRAME
    assert_silent_outcome "signed_out", "no marker: the client keeps no cookies or runs no script"

    cookies[EverySilentSignIn::TRIED_COOKIE] = "asking"
    get "/session/silent", headers: { "Sec-Fetch-Dest" => "document" }
    assert_silent_outcome "signed_out", "opened as a page"

    cookies[EverySilentSignIn::TRIED_COOKIE] = "declined"
    get "/session/silent", headers: FRAME
    assert_silent_outcome "signed_out", "Every already said no"

    cookies[EverySilentSignIn::TRIED_COOKIE] = "asking"
    cookies[EverySilentSignIn::SIGNED_OUT_COOKIE] = "1"
    get "/session/silent", headers: FRAME
    assert_silent_outcome "signed_out", "signed out on purpose"
    cookies.delete(EverySilentSignIn::SIGNED_OUT_COOKIE)

    Rails.application.config.x.every_oauth.scope = "basic_profile"
    get "/session/silent", headers: FRAME
    assert_silent_outcome "signed_out", "no openid"
  end

  test "a browser that is already signed in is told so without asking Every" do
    sign_in_as(users(:every_ana))
    cookies[EverySilentSignIn::TRIED_COOKIE] = "asking"

    get "/session/silent", headers: FRAME

    assert_silent_outcome "signed_in"
  end

  test "the frame is never sent to onboarding: a member who has not finished it gets the tiny page too" do
    sign_in_as(users(:one))
    cookies[EverySilentSignIn::TRIED_COOKIE] = "asking"

    get "/session/silent", headers: FRAME

    assert_silent_outcome "signed_in"
  end

  test "the tiny page is not stored, not indexed, runs no script and is not an Inertia page" do
    get "/session/silent", headers: FRAME

    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal "noindex", response.headers["X-Robots-Tag"]
    assert_no_match(/<script|data-page/, response.body)
  end

  # The answer

  test "a browser signed in to every.to is signed in here, on the tiny page" do
    stub_every_token
    stub_every_userinfo

    assert_difference -> { User.count } => 1, -> { Session.count } => 1 do
      complete_silent_attempt(code: "authorization-code")
    end

    assert_silent_outcome "signed_in"
    assert_empty cookies[OmniAuth::Strategies::Every::SILENT_STATE_COOKIE].to_s
    assert_empty cookies[EverySilentSignIn::TRIED_COOKIE].to_s
    assert_no_match(/_session=/, response.headers["Set-Cookie"].to_s)
    assert_equal "4242", Session.last.user.every_user_id
  end

  test "the page around the frame reloads its props as the member" do
    ana = users(:every_ana)
    stub_every_token
    stub_every_userinfo(every_payload("userinfo", user_id: ana.every_user_id, email: ana.email_address, name: ana.name))
    complete_silent_attempt(code: "authorization-code")
    assert_silent_outcome "signed_in"

    get root_path, headers: inertia_reload

    assert_response :success
    assert_equal [ "home/index", "Ana Every" ], [ response.parsed_body["component"], response.parsed_body.dig("props", "current_user", "name") ]
    assert response.parsed_body.dig("props", "webmcp").present?, "the agent tools register"
    assert_nil response.parsed_body.dig("props", "silent_sign_in_path")
  end

  test "a member who has not finished onboarding is sent to /welcome by that reload, as after a click" do
    stub_every_token
    stub_every_userinfo
    complete_silent_attempt(code: "authorization-code")
    assert_silent_outcome "signed_in", "the frame itself is not gated"
    assert_not User.find_by!(every_user_id: "4242").onboarded?

    [ root_path, kind_path("coding"), profile_path("ana") ].each do |path|
      get path, headers: inertia_reload
      assert_redirected_to welcome_url, path
    end

    follow_redirect! headers: inertia_reload
    assert_response :success
    assert_equal [ "onboarding/show", "Bo Every" ], [ response.parsed_body["component"], response.parsed_body.dig("props", "current_user", "name") ]
  end

  test "on the sign-in page that reload goes on to the page that asked for sign-in" do
    ana = users(:every_ana)
    stub_every_token
    stub_every_userinfo(every_payload("userinfo", user_id: ana.every_user_id, email: ana.email_address))
    get edit_toolbox_path
    assert_redirected_to new_session_url
    complete_silent_attempt(code: "authorization-code")

    get new_session_path, headers: inertia_reload

    assert_redirected_to edit_toolbox_url
  end

  %w[login_required consent_required].each do |answer|
    test "Every's #{answer} is a quiet no that stands for a day" do
      assert_no_difference [ "User.count", "Session.count" ] do
        complete_silent_attempt(error: answer)
      end

      assert_silent_outcome "signed_out"
      assert_equal "declined", cookies[EverySilentSignIn::TRIED_COOKIE]

      get root_path
      assert_empty inertia.props[:flash]
      assert_nil inertia.props[:silent_sign_in_path]

      travel EverySilentSignIn::DECLINE_TTL - 1.hour do
        get root_path
        assert_nil inertia.props[:silent_sign_in_path]
      end
      travel EverySilentSignIn::DECLINE_TTL + 1.minute do
        get root_path
        assert_equal "/session/silent", inertia.props[:silent_sign_in_path]
      end
    end
  end

  test "a failure is a quiet no that stands for ten minutes" do
    start_silent_attempt
    get "/auth/every/callback", params: { code: "authorization-code", state: "silent.forged" }
    assert_silent_outcome "signed_out", "state mismatch"
    assert_equal "tried", cookies[EverySilentSignIn::TRIED_COOKIE]

    cookies[EverySilentSignIn::TRIED_COOKIE] = "asking"
    stub_every_token(status: 400, payload: every_payload("token_invalid_grant"))
    complete_silent_attempt(code: "authorization-code")
    assert_silent_outcome "signed_out", "rejected code"

    cookies[EverySilentSignIn::TRIED_COOKIE] = "asking"
    stub_every_token
    stub_every_userinfo(every_payload("userinfo").except("email"))
    complete_silent_attempt(code: "authorization-code")
    assert_silent_outcome "signed_out", "userinfo without an email"
    assert_equal "tried", cookies[EverySilentSignIn::TRIED_COOKIE]

    cookies[EverySilentSignIn::TRIED_COOKIE] = "asking"
    stub_request(:get, "#{EVERY_BASE}/oauth/userinfo").to_return(status: 200, body: "<html>down</html>", headers: { "Content-Type" => "text/html" })
    complete_silent_attempt(code: "authorization-code")
    assert_silent_outcome "signed_out", "an answer that is not JSON"
    assert_equal "tried", cookies[EverySilentSignIn::TRIED_COOKIE]

    get root_path
    assert_empty inertia.props[:flash]
    travel EverySilentSignIn::ATTEMPT_TTL + 1.minute do
      get root_path
      assert_equal "/session/silent", inertia.props[:silent_sign_in_path]
    end
  end

  test "an account that cannot be saved is a quiet no too" do
    stub_every_token
    stub_every_userinfo(every_payload("userinfo", user_id: 9999, email: users(:every_ana).email_address))

    assert_no_difference -> { Session.count } do
      complete_silent_attempt(code: "authorization-code")
    end

    assert_silent_outcome "signed_out"
    assert_equal "tried", cookies[EverySilentSignIn::TRIED_COOKIE]
    assert_equal "every-user-ana", users(:every_ana).reload.every_user_id
  end

  test "signing out while the frame is asking sticks" do
    stub_every_token
    stub_every_userinfo
    state = start_silent_attempt
    cookies[EverySilentSignIn::SIGNED_OUT_COOKIE] = "1"

    assert_no_difference -> { Session.count } do
      get "/auth/every/callback", params: { code: "authorization-code", state: }
    end

    assert_silent_outcome "signed_out"
  end

  test "an explicit email_verified false is refused, and clears the team status the account had" do
    ana = users(:every_ana)
    stub_every_token
    stub_every_userinfo(every_payload("userinfo", user_id: ana.every_user_id, email: ana.email_address, email_verified: false))

    assert_no_difference -> { Session.count } do
      complete_silent_attempt(code: "authorization-code")
    end

    assert_silent_outcome "signed_out"
    assert_not ana.reload.email_verified?
    assert_not ana.every_member?
  end

  test "the framed path applies the same team rule as a click: only a verified @every.to address is the Every team" do
    stub_every_token
    stub_every_userinfo(every_payload("userinfo_gmail"))
    complete_silent_attempt(code: "authorization-code")
    assert_silent_outcome "signed_in"
    assert_not User.find_by!(email_address: "someone@gmail.com").every_member?

    sign_out
    cookies[EverySilentSignIn::TRIED_COOKIE] = "asking"
    stub_every_userinfo(every_payload("userinfo").except("email_verified"))
    complete_silent_attempt(code: "authorization-code")
    assert_silent_outcome "signed_in"
    assert User.find_by!(every_user_id: "4242").every_member?
  end

  test "a callback with a framed state that the strategy never saw answers no" do
    Rails.application.config.x.every_oauth.client_id = nil

    get "/auth/every/callback", params: { code: "authorization-code", state: "silent.abc" }

    assert_silent_outcome "signed_out"
  end

  # Beside a clicked sign-in

  test "a click under way is untouched by a framed attempt that Every declines" do
    ana = users(:every_ana)
    stub_every_token
    stub_every_userinfo(every_payload("userinfo", user_id: ana.every_user_id, email: ana.email_address))
    get edit_toolbox_path
    assert_redirected_to new_session_url
    click_state = start_every_sign_in

    complete_silent_attempt(error: "login_required")
    assert_silent_outcome "signed_out"

    assert_difference -> { Session.count } => 1 do
      get "/auth/every/callback", params: { code: "authorization-code", state: click_state }
    end
    assert_redirected_to edit_toolbox_url
    assert_nil flash[:alert]
  end

  test "a framed answer that arrives after a click signed the person in changes nothing" do
    stub_every_token
    stub_every_userinfo
    silent_state = start_silent_attempt
    click_state = start_every_sign_in
    get "/auth/every/callback", params: { code: "authorization-code", state: click_state }
    assert_redirected_to welcome_url

    assert_no_difference -> { Session.count } do
      get "/auth/every/callback", params: { code: "authorization-code", state: silent_state }
    end
    assert_silent_outcome "signed_in"
  end

  private

  # What Inertia sends when a page fetches its props again (router.reload).
  def inertia_reload
    { "X-Inertia" => "true", "X-Inertia-Version" => InertiaRails.configuration.version.to_s }
  end

  # What the browser module does before it frames, then the frame's first request.
  def start_silent_attempt
    cookies["every_silent_tried"] = "asking"
    get "/session/silent", headers: FRAME
    Rack::Utils.parse_query(URI(response.location).query).fetch("state")
  end

  def complete_silent_attempt(**answer)
    get "/auth/every/callback", params: answer.merge(state: start_silent_attempt)
  end

  def assert_silent_outcome(outcome, message = nil)
    assert_response :success, message
    assert_nil response.headers["Location"], message
    assert_select "body[data-silent-sign-in=?]", outcome, { count: 1 }, message
  end
end
