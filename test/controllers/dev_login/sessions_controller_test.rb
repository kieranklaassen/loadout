require "test_helper"

# The dev login routes are drawn only in development, so this drives the controller
# with a route of its own and the development guard switched on and off.
class DevLogin::SessionsControllerTest < ActionController::TestCase
  tests DevLogin::SessionsController

  def login(email, development:)
    with_routing do |routes|
      routes.draw do
        post "dev/login" => "dev_login/sessions#create"
        resource :session, only: %i[new]
        root "home#index"
      end
      with_development_env(development) { post :create, params: { email_address: email } }
    end
  end

  # A singleton override on the memoized Rails.env removes cleanly and reveals the real method again.
  def with_development_env(value)
    env = Rails.env
    env.define_singleton_method(:development?) { value }
    yield
  ensure
    env.singleton_class.send(:remove_method, :development?)
  end

  test "in development it signs in a seeded person and counts them as verified Every staff" do
    person = users(:every_fay)
    assert_not person.every_member?

    assert_difference -> { Session.count } => 1 do
      login(person.email_address, development: true)
    end

    assert_response :see_other
    assert person.reload.email_verified?
    assert person.every_member?
  end

  test "an address nobody was seeded with goes back to the sign-in page" do
    assert_no_difference -> { Session.count } do
      login("nobody@every.to", development: true)
    end

    assert_redirected_to "/session/new"
  end

  test "anywhere but development it does nothing" do
    person = users(:every_fay)

    assert_no_difference -> { Session.count } do
      login(person.email_address, development: false)
    end

    assert_response :not_found
    assert_not person.reload.email_verified?
  end
end
