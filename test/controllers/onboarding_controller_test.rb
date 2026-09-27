require "test_helper"

class OnboardingControllerTest < ActionDispatch::IntegrationTest
  test "the first sign-in redirects any page to /welcome" do
    sign_in_as users(:one)

    get edit_loadout_path
    assert_redirected_to welcome_path

    get settings_path
    assert_redirected_to welcome_path
  end

  test "an onboarded member is not gated" do
    sign_in_as users(:every_ana)

    get edit_loadout_path

    assert_response :success
  end

  test "signed-out visitors are not sent to onboarding" do
    get new_session_path

    assert_response :success
    assert_inertia_component "auth/sign_in"
  end

  test "controllers can opt out of the gate" do
    assert_includes LoadoutsController.__callbacks[:process_action].map(&:filter), :require_onboarding
    assert_not OnboardingController.__callbacks[:process_action].map(&:filter).include?(:require_onboarding)
    assert_not SessionsController.__callbacks[:process_action].map(&:filter).include?(:require_onboarding)
    assert_not HandlesController.__callbacks[:process_action].map(&:filter).include?(:require_onboarding)
  end

  test "welcome is one page: a suggested handle, the name, private by default and two real kinds for the preview" do
    users(:one).update!(name: "Olive Jones", avatar_url: "https://every.to/avatars/olive.png")
    sign_in_as users(:one)

    get welcome_path

    assert_response :success
    assert_inertia_component "onboarding/show"
    props = inertia.props
    assert_equal "olive-jones", props[:suggested_handle]
    assert_equal "Olive Jones", props[:name]
    assert_equal "https://every.to/avatars/olive.png", props[:avatar_url]
    assert_equal "only_me", props[:visibility]
    assert_equal [ "Coding", "Knowledge work" ], props[:preview_kinds]
    assert_not props.key?(:picker), "the picker belongs to the editor now"
    assert_not props.key?(:step)
  end

  test "abandoning the page leaves an empty private member who is not onboarded" do
    sign_in_as users(:one)

    get welcome_path

    user = users(:one).reload
    assert_equal "only_me", user.visibility
    assert_nil user.handle
    assert_not user.onboarded?
    assert_empty user.entries
    assert_empty user.visibility_periods
  end

  test "claiming a handle with a visibility stores both, marks the member onboarded and continues to the editor" do
    sign_in_as users(:one)

    patch welcome_path, params: { handle: "Olive", visibility: "team" }

    assert_redirected_to edit_loadout_path
    assert_response :see_other
    user = users(:one).reload
    assert_equal [ "olive", "team" ], [ user.handle, user.visibility ]
    assert user.onboarded?
    period = user.visibility_periods.sole
    assert_equal "team", period.level
    assert_nil period.ends_at
  end

  test "choosing anyone with the link opens a link period" do
    sign_in_as users(:one)

    patch welcome_path, params: { handle: "olive", visibility: "link" }

    assert_equal "link", users(:one).reload.visibility
    assert_equal [ "link" ], users(:one).visibility_periods.map(&:level)
  end

  test "without a visibility the member stays private and no period opens" do
    sign_in_as users(:one)

    patch welcome_path, params: { handle: "olive" }

    assert_redirected_to edit_loadout_path
    user = users(:one).reload
    assert user.onboarded?
    assert_equal "only_me", user.visibility
    assert_empty user.visibility_periods
  end

  test "an unknown visibility is rejected and nothing is saved" do
    sign_in_as users(:one)

    %w[public private everyone].each do |level|
      patch welcome_path, params: { handle: "olive", visibility: level }

      assert_redirected_to welcome_path
      follow_redirect!
      assert inertia.props[:errors][:visibility].present?, "#{level} should be refused"
    end

    user = users(:one).reload
    assert_nil user.handle
    assert_equal "only_me", user.visibility
    assert_not user.onboarded?
  end

  test "a reserved handle is rejected with a message" do
    sign_in_as users(:one)

    patch welcome_path, params: { handle: "map", visibility: "team" }

    assert_redirected_to welcome_path
    follow_redirect!
    assert_equal "#{LoadoutHost::DEFAULT_HOST}/map is reserved.", inertia.props[:errors][:handle]
    user = users(:one).reload
    assert_nil user.handle
    assert_equal "only_me", user.visibility
    assert_not user.onboarded?
  end

  test "a taken handle is rejected with a message" do
    sign_in_as users(:one)

    patch welcome_path, params: { handle: "ana" }

    assert_nil users(:one).reload.handle
    follow_redirect!
    assert_equal "#{LoadoutHost::DEFAULT_HOST}/ana is taken.", inertia.props[:errors][:handle]
  end

  test "a blank handle is rejected" do
    sign_in_as users(:one)

    patch welcome_path, params: { handle: " ", visibility: "link" }

    follow_redirect!
    assert_equal "Pick a handle.", inertia.props[:errors][:handle]
    assert_not users(:one).reload.onboarded?
  end

  test "an onboarded member visiting or submitting welcome goes to the editor" do
    sign_in_as users(:every_ana)

    get welcome_path
    assert_redirected_to edit_loadout_path

    patch welcome_path, params: { handle: "ana-two", visibility: "only_me" }
    assert_redirected_to edit_loadout_path
    assert_equal [ "ana", "link" ], users(:every_ana).reload.slice(:handle, :visibility).values
  end
end
