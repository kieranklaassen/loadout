require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "new renders the auth/sign_in Inertia page without dev login people outside development" do
    get new_session_path

    assert_response :success
    assert_inertia_component "auth/sign_in"
    assert_not inertia.props.key?(:dev_login_people)
    assert_equal "https://every.to", inertia.props[:join_every_url]
  end

  test "there is no password sign-in" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/session", method: :post)
    end
    assert_not User.new.respond_to?(:authenticate)
  end

  test "destroy terminates the session when signed in" do
    sign_in_as(users(:every_ana))

    delete session_path

    assert_redirected_to root_path
    assert_empty cookies[:session_id]
  end

  test "destroy requires a session" do
    delete session_path

    assert_redirected_to new_session_path
  end
end
