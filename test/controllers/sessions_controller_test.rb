require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  PASSWORD = "Secret-Passw0rd" # matches test/fixtures/users.yml

  setup do
    @user = users(:one)
    # Owned in-memory store persists across requests in-process; reset per test
    # so rate-limit counts from one test never leak into another.
    SessionsController::RATE_LIMIT_STORE.clear
  end

  test "new renders the auth/sign_in Inertia page" do
    get new_session_path

    assert_response :success
    assert_inertia_component "auth/sign_in"
  end

  test "create with valid credentials starts a session and sets the signed cookie" do
    assert_difference -> { @user.sessions.count }, 1 do
      post session_path, params: { email_address: @user.email_address, password: PASSWORD }
    end

    assert_redirected_to root_path
    assert cookies[:session_id].present?
  end

  test "create with a wrong password fails generically and starts no session" do
    assert_no_difference -> { Session.count } do
      post session_path, params: { email_address: @user.email_address, password: "wrong-password-xx" }
    end

    assert_redirected_to new_session_path
    assert_equal "Invalid email or password.", flash[:alert]
    assert_nil cookies[:session_id].presence
  end

  test "unknown email returns a byte-identical message to a wrong password (no enumeration oracle)" do
    post session_path, params: { email_address: @user.email_address, password: "wrong-password-xx" }
    wrong_password_message = flash[:alert]

    post session_path, params: { email_address: "does-not-exist@example.com", password: "wrong-password-xx" }
    unknown_email_message = flash[:alert]

    assert_equal wrong_password_message, unknown_email_message
  end

  test "the 11th attempt within the window is throttled by the owned store" do
    10.times do
      post session_path, params: { email_address: @user.email_address, password: "wrong-password-xx" }
      assert_equal "Invalid email or password.", flash[:alert]
    end

    post session_path, params: { email_address: @user.email_address, password: "wrong-password-xx" }
    assert_redirected_to new_session_path
    assert_match(/too many/i, flash[:alert])
  end

  test "require_authentication redirects an unauthenticated request away from a gated action" do
    # destroy is gated (only new/create allow unauthenticated access).
    delete session_path

    assert_redirected_to new_session_path
  end

  test "destroy terminates the session when signed in" do
    sign_in_as(@user)

    delete session_path

    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
  end
end
