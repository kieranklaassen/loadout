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
    stub_every_userinfo

    assert_difference -> { User.count } => 1, -> { Session.count } => 1 do
      complete_every_sign_in
    end

    assert_redirected_to "http://www.example.com/welcome".sub("http:", "https:")
    user = User.find_by!(every_user_id: "4242")
    assert_equal [ "bo@every.to", "Bo Every", "https://every.to/avatars/bo.png" ], [ user.email_address, user.name, user.avatar_url ]
    assert user.every_member?
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
    stub_every_userinfo(every_payload("userinfo", email: "bo@every.to.evil.com"))
    complete_every_sign_in
    assert_not User.find_by!(every_user_id: "4242").every_member?

    stub_every_userinfo(every_payload("userinfo", email: "bo@EVERY.TO "))
    complete_every_sign_in
    assert_equal "bo@every.to", User.find_by!(every_user_id: "4242").email_address
  end

  test "an explicit email_verified false is refused" do
    stub_every_token
    stub_every_userinfo(every_payload("userinfo", email_verified: false))

    assert_no_difference -> { Session.count } do
      complete_every_sign_in
    end

    assert_redirected_to new_session_url
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

    assert_redirected_to new_session_url
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

    assert_redirected_to new_session_url
    assert_equal "Sign in with Every did not complete. Try again.", flash[:alert]
    assert_empty cookies[:session_id].to_s
  end

  test "an OAuth failure from Every lands on the sign-in page with an error and no session" do
    state = start_every_sign_in

    assert_no_difference -> { Session.count } do
      get "/auth/every/callback", params: { error: "access_denied", state: state }
    end

    assert_redirected_to new_session_url
    assert_equal "Sign in with Every did not complete. Try again.", flash[:alert]
  end

  test "a rejected code lands on the sign-in page with an error and no session" do
    stub_every_token(status: 400, payload: every_payload("token_invalid_grant"))

    assert_no_difference -> { Session.count } do
      complete_every_sign_in
    end

    assert_redirected_to new_session_url
    assert flash[:alert].present?
  end

  test "an unconfigured client says so on the sign-in page" do
    Rails.application.config.x.every_oauth.client_id = nil

    get "/auth/every"

    assert_redirected_to new_session_url
    assert_equal "Sign in with Every is not configured on this server.", flash[:alert]
  end

  test "the sign-in start is allowed by GET" do
    get "/auth/every"

    assert_response :redirect
    assert response.location.start_with?("#{EveryOauthHelper::EVERY_BASE}/oauth/authorize?")
  end

  private

  def start_every_sign_in
    get "/auth/every"
    assert_response :redirect
    Rack::Utils.parse_query(URI(response.location).query).fetch("state")
  end

  def complete_every_sign_in
    state = start_every_sign_in
    get "/auth/every/callback", params: { code: "authorization-code", state: state }
  end
end
