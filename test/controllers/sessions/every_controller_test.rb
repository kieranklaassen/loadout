require "test_helper"

# Drives the real OmniAuth middleware against the recorded Every payloads.
# https! because the __Host- state cookie is Secure.
class Sessions::EveryControllerTest < ActionDispatch::IntegrationTest
  setup do
    configure_every_oauth
    https!
  end

  teardown { restore_every_oauth }

  test "a verified callback creates the user and a session, then sends a new member to onboarding" do
    stub_every_token
    stub_every_userinfo(every_payload("userinfo", email_verified: true))

    assert_difference -> { User.count } => 1, -> { Session.count } => 1 do
      complete_every_sign_in
    end

    assert_redirected_to "http://www.example.com/welcome".sub("http:", "https:")
    user = User.find_by!(every_user_id: "4242")
    assert_equal [ "bo@every.to", "Bo Every", "https://every.to/avatars/bo.png" ], [ user.email_address, user.name, user.avatar_url ]
    assert user.every_member?
    assert user.email_verified?
    assert_equal user, Session.last.user
    assert cookies[:session_id].present?
    assert_empty cookies[OmniAuth::Strategies::Every::STATE_COOKIE].to_s
  end

  test "anyone with an Every account can sign in; a gmail.com member is not an Every member" do
    stub_every_token
    stub_every_userinfo(every_payload("userinfo_gmail"))

    assert_difference -> { User.count } => 1, -> { Session.count } => 1 do
      complete_every_sign_in
    end

    assert_redirected_to "http://www.example.com/welcome".sub("http:", "https:")
    assert_not User.find_by!(email_address: "someone@gmail.com").every_member?
  end

  test "a look-alike domain is not an Every member and a padded upper-case every.to address is normalized" do
    stub_every_token
    stub_every_userinfo(every_payload("userinfo", email: "bo@every.to.evil.com", email_verified: true))
    complete_every_sign_in
    assert_not User.find_by!(every_user_id: "4242").every_member?

    stub_every_userinfo(every_payload("userinfo", email: "bo@EVERY.TO ", email_verified: true))
    complete_every_sign_in
    assert_equal "bo@every.to", User.find_by!(every_user_id: "4242").email_address
    assert User.find_by!(every_user_id: "4242").every_member?
  end

  test "AE11: none of these addresses is the Every team, verified or not" do
    stub_every_token
    [ "ana@every.to.evil.com", "a@b@every.to", "x@sub.every.to", "ana@evil-every.to" ].each_with_index do |email, index|
      stub_every_userinfo(every_payload("userinfo", user_id: 7000 + index, email:, email_verified: true))
      complete_every_sign_in

      person = User.find_by!(every_user_id: (7000 + index).to_s)
      assert_not person.every_member?, email
      assert_not User.every_members.exists?(id: person.id), email
    end
  end

  test "Every's UserInfo without an email_verified claim makes an @every.to address the Every team" do
    stub_every_token
    stub_every_userinfo(every_payload("userinfo").except("email_verified"))

    assert_difference -> { Session.count } => 1 do
      complete_every_sign_in
    end

    person = User.find_by!(every_user_id: "4242")
    assert person.email_verified?
    assert person.every_member?
    assert User.every_members.exists?(id: person.id)
  end

  test "any claim but an explicit false counts as verified" do
    stub_every_token
    stub_every_userinfo(every_payload("userinfo", user_id: 4243, email: "claimed@every.to", email_verified: "true"))

    complete_every_sign_in

    assert User.find_by!(every_user_id: "4243").every_member?
  end

  test "a sign-in after an explicit false restores team status" do
    stub_every_token
    stub_every_userinfo(every_payload("userinfo", email_verified: false))
    complete_every_sign_in
    assert_nil User.find_by(every_user_id: "4242")

    stub_every_userinfo(every_payload("userinfo"))
    complete_every_sign_in
    assert User.find_by!(every_user_id: "4242").every_member?
  end

  test "an ADMIN_EMAILS address is admin with no email_verified claim" do
    ENV["ADMIN_EMAILS"] = "bo@every.to"
    stub_every_token
    stub_every_userinfo(every_payload("userinfo"))
    complete_every_sign_in

    assert User.find_by!(every_user_id: "4242").admin?
  ensure
    ENV.delete("ADMIN_EMAILS")
  end

  # Silent sign-in and sign-out

  test "the sign-in page first asks Every silently for openid basic_profile" do
    get new_session_path

    assert_redirected_to "/auth/every?prompt=none"
    follow_redirect!
    params = Rack::Utils.parse_query(URI(response.location).query)
    assert_equal [ "none", "openid basic_profile" ], params.values_at("prompt", "scope")
  end

  test "an Inertia visit to the sign-in page is sent to Every as a full navigation" do
    get new_session_path, headers: { "X-Inertia" => "true", "X-Inertia-Version" => InertiaRails.configuration.version.to_s }

    assert_response :conflict
    assert_equal "/auth/every?prompt=none", response.headers["X-Inertia-Location"]
  end

  test "a browser signed in to every.to as a trusted app lands signed in without seeing a page" do
    stub_every_token
    stub_every_userinfo

    get new_session_path
    follow_redirect!
    state = Rack::Utils.parse_query(URI(response.location).query).fetch("state")

    assert_difference -> { Session.count } => 1 do
      get "/auth/every/callback", params: { code: "authorization-code", state: }
    end
    assert_redirected_to "https://www.example.com/welcome"
  end

  %w[login_required consent_required].each do |answer|
    test "Every's #{answer} falls back to the sign-in page once, with no error and no loop" do
      get new_session_path
      follow_redirect!
      state = Rack::Utils.parse_query(URI(response.location).query).fetch("state")

      get "/auth/every/callback", params: { error: answer, state: }
      assert_redirected_to new_session_url(silent: "tried")
      assert_nil flash[:alert]

      follow_redirect!
      assert_response :success
      assert_inertia_component "auth/sign_in"
    end
  end

  test "a decline stands for a day, on the sign-in page too" do
    get new_session_path
    follow_redirect!
    state = Rack::Utils.parse_query(URI(response.location).query).fetch("state")
    get "/auth/every/callback", params: { error: "login_required", state: }

    assert_equal "declined", cookies[EverySilentSignIn::TRIED_COOKIE]
    travel EverySilentSignIn::ATTEMPT_TTL + 1.second do
      get new_session_path
      assert_response :success
    end
    travel EverySilentSignIn::DECLINE_TTL + 1.second do
      get new_session_path
      assert_redirected_to "/auth/every?prompt=none"
    end
  end

  test "a client that keeps no cookies is asked once, not in a loop" do
    get new_session_path
    follow_redirect!
    state = Rack::Utils.parse_query(URI(response.location).query).fetch("state")
    cookies.to_hash.each_key { |name| cookies.delete(name) }

    get "/auth/every/callback", params: { error: "login_required", state: }
    assert_redirected_to new_session_url(silent: "tried")

    cookies.to_hash.each_key { |name| cookies.delete(name) }
    follow_redirect!
    assert_response :success
    assert_inertia_component "auth/sign_in"
  end

  test "a silent attempt that fails for any other reason says nothing either" do
    get new_session_path
    follow_redirect!
    state = Rack::Utils.parse_query(URI(response.location).query).fetch("state")
    cookies.delete(OmniAuth::Strategies::Every::STATE_COOKIE)

    get "/auth/every/callback", params: { code: "authorization-code", state: }

    assert_redirected_to new_session_url(silent: "tried")
    assert_nil flash[:alert]
  end

  test "a frame that was started and never answered does not stop the sign-in page from asking" do
    cookies[EverySilentSignIn::TRIED_COOKIE] = "asking"

    get new_session_path

    assert_redirected_to "/auth/every?prompt=none"
    assert_equal "tried", cookies[EverySilentSignIn::TRIED_COOKIE]
  end

  test "the sign-in page tries silently again once the last attempt is old" do
    get new_session_path
    follow_redirect!
    state = Rack::Utils.parse_query(URI(response.location).query).fetch("state")
    cookies.delete(OmniAuth::Strategies::Every::STATE_COOKIE)
    get "/auth/every/callback", params: { code: "authorization-code", state: }

    get new_session_path
    assert_response :success
    travel EverySilentSignIn::ATTEMPT_TTL + 1.second do
      get new_session_path
      assert_redirected_to "/auth/every?prompt=none"
    end
  end

  test "a sign-in error is shown on the page instead of starting a silent attempt" do
    get "/auth/every"
    get "/auth/every/callback", params: { code: "authorization-code", state: "forged" }
    follow_redirect!

    assert_response :success
    assert_equal "Sign in with Every did not complete. Try again.", flash[:alert]
  end

  test "signing out sticks: no silent sign-in until the person signs in with Every again" do
    stub_every_token
    stub_every_userinfo(every_payload("userinfo", user_id: users(:every_ana).every_user_id, email: users(:every_ana).email_address))
    complete_every_sign_in

    delete session_path
    assert cookies[EverySilentSignIn::SIGNED_OUT_COOKIE].present?

    get new_session_path
    assert_response :success
    assert_inertia_component "auth/sign_in"

    complete_every_sign_in
    assert_empty cookies[EverySilentSignIn::SIGNED_OUT_COOKIE].to_s
    delete session_path
    travel EverySilentSignIn::ATTEMPT_TTL + 1.second do
      get new_session_path
      assert_response :success, "signing out again sticks again"
    end
  end

  test "with basic_profile alone the sign-in page renders without a silent attempt" do
    Rails.application.config.x.every_oauth.scope = "basic_profile"

    get new_session_path

    assert_response :success
    assert_inertia_component "auth/sign_in"
  end

  test "an explicit email_verified false is refused" do
    stub_every_token
    stub_every_userinfo(every_payload("userinfo", email_verified: false))

    assert_no_difference -> { Session.count } do
      complete_every_sign_in
    end

    assert_redirected_to new_session_url(silent: "tried")
  end

  test "an explicit false also clears the team status the account had" do
    ana = users(:every_ana)
    assert ana.every_member?
    stub_every_token
    stub_every_userinfo(every_payload("userinfo", user_id: ana.every_user_id, email: ana.email_address, email_verified: false))

    assert_no_difference -> { Session.count } do
      complete_every_sign_in
    end

    assert_not ana.reload.email_verified?
    assert_not ana.every_member?
  end

  test "a new member signing in to approve an agent goes straight back to the consent screen" do
    stub_every_token
    stub_every_userinfo
    client_id = register_client
    _verifier, challenge = pkce_pair
    get "/oauth/authorize", params: authorization_params(client_id:, challenge:).except(:resource)
    assert_redirected_to new_session_url

    complete_every_sign_in

    assert_match %r{/oauth/authorize\?}, response.location
  end

  test "an onboarded member returns to where they were going" do
    ana = users(:every_ana)
    stub_every_token
    stub_every_userinfo(every_payload("userinfo", user_id: ana.every_user_id, email: ana.email_address))

    complete_every_sign_in

    assert_redirected_to root_url
  end

  test "a returning user whose Every name changed gets the new name" do
    ana = users(:every_ana)
    stub_every_token
    stub_every_userinfo(every_payload("userinfo", user_id: ana.every_user_id, email: ana.email_address, name: "Ana Renamed", avatar_url: nil))

    assert_no_difference -> { User.count } do
      complete_every_sign_in
    end

    ana.reload
    assert_equal "Ana Renamed", ana.name
    assert_nil ana.avatar_url
  end

  test "a seeded person without an Every identity is adopted by email on first sign-in" do
    person = User.create!(email_address: "bo@every.to")
    stub_every_token
    stub_every_userinfo

    complete_every_sign_in

    assert_equal "4242", person.reload.every_user_id
  end

  test "a new Every account cannot take over an existing SSO user's row through a reused email" do
    stub_every_token
    stub_every_userinfo(every_payload("userinfo", user_id: 9999, email: users(:every_ana).email_address))

    assert_no_difference -> { Session.count } do
      complete_every_sign_in
    end

    assert_redirected_to new_session_url(silent: "tried")
    assert_equal "every-user-ana", users(:every_ana).reload.every_user_id
  end

  test "an already signed-in browser keeps one session" do
    stub_every_token
    stub_every_userinfo
    complete_every_sign_in

    assert_no_difference -> { Session.count } do
      complete_every_sign_in
    end
  end

  test "a state mismatch lands on the sign-in page with an error and no session" do
    get "/auth/every"

    assert_no_difference -> { Session.count } do
      get "/auth/every/callback", params: { code: "authorization-code", state: "forged" }
    end

    assert_redirected_to new_session_url(silent: "tried")
    assert_equal "Sign in with Every did not complete. Try again.", flash[:alert]
    assert_empty cookies[:session_id].to_s
  end

  test "an OAuth failure from Every lands on the sign-in page with an error and no session" do
    state = start_every_sign_in

    assert_no_difference -> { Session.count } do
      get "/auth/every/callback", params: { error: "access_denied", state: state }
    end

    assert_redirected_to new_session_url(silent: "tried")
    assert_equal "Sign in with Every did not complete. Try again.", flash[:alert]
  end

  test "a rejected code lands on the sign-in page with an error and no session" do
    stub_every_token(status: 400, payload: every_payload("token_invalid_grant"))

    assert_no_difference -> { Session.count } do
      complete_every_sign_in
    end

    assert_redirected_to new_session_url(silent: "tried")
    assert flash[:alert].present?
  end

  test "an unconfigured client says so on the sign-in page" do
    Rails.application.config.x.every_oauth.client_id = nil

    get "/auth/every"

    assert_redirected_to new_session_url(silent: "tried")
    assert_equal "Sign in with Every is not configured on this server.", flash[:alert]
  end

  test "the sign-in start is allowed by GET" do
    get "/auth/every"

    assert_response :redirect
    assert response.location.start_with?("#{EveryOauthHelper::EVERY_BASE}/oauth/authorize?")
  end

  private

  def complete_every_sign_in
    state = start_every_sign_in
    get "/auth/every/callback", params: { code: "authorization-code", state: state }
  end
end
