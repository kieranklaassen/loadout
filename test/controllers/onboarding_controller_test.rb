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
    get root_path

    assert_response :success
    assert_inertia_component "home/index"
  end

  test "controllers can opt out of the gate" do
    assert_includes LoadoutsController.__callbacks[:process_action].map(&:filter), :require_onboarding
    assert_not OnboardingController.__callbacks[:process_action].map(&:filter).include?(:require_onboarding)
    assert_not SessionsController.__callbacks[:process_action].map(&:filter).include?(:require_onboarding)
    assert_not HandlesController.__callbacks[:process_action].map(&:filter).include?(:require_onboarding)
  end

  test "welcome starts at the claim step with a suggested handle" do
    users(:one).update!(name: "Olive Jones")
    sign_in_as users(:one)

    get welcome_path

    assert_response :success
    assert_inertia_component "onboarding/show"
    assert_equal "handle", inertia.props[:step]
    assert_equal "olive-jones", inertia.props[:suggested_handle]
    assert_equal "Olive", inertia.props[:first_name]
    assert_equal Category.count, inertia.props[:picker][:categories].size
  end

  test "claiming a free handle moves on to the picker" do
    sign_in_as users(:one)

    patch welcome_handle_path, params: { handle: "Olive" }

    assert_redirected_to welcome_path
    assert_equal "olive", users(:one).reload.handle
    follow_redirect!
    assert_equal "picks", inertia.props[:step]
  end

  test "a reserved handle is rejected with a message" do
    sign_in_as users(:one)

    patch welcome_handle_path, params: { handle: "map" }

    assert_redirected_to welcome_path(step: "handle")
    assert_nil users(:one).reload.handle
    follow_redirect!
    assert_equal "loadout.every.to/map is reserved.", inertia.props[:errors][:handle]
  end

  test "a taken handle is rejected with a message" do
    sign_in_as users(:one)

    patch welcome_handle_path, params: { handle: "ana" }

    assert_nil users(:one).reload.handle
    follow_redirect!
    assert_equal "loadout.every.to/ana is taken.", inertia.props[:errors][:handle]
  end

  test "the picker save creates entries and web changes" do
    user = users(:one)
    user.update!(handle: "olive")
    sign_in_as user

    patch loadout_path, params: {
      operations: [
        { op: "replace_category", category: "coding", picks: [ { tool: "cursor", model: "claude-opus-5-5", primary: true }, { tool: "claude-code" } ] },
        { op: "replace_category", category: "video", picks: [ { tool: "Hedra" } ] }
      ]
    }, headers: { "Referer" => "http://www.example.com/welcome" }, as: :json

    assert_redirected_to "http://www.example.com/welcome"
    assert_equal 3, user.entries.count
    assert user.entries.find_by(tool: tools(:cursor)).primary?
    assert_equal %w[web], user.entry_changes.distinct.pluck(:source)
    assert Tool.find_by(name: "Hedra").pending?
  end

  test "finishing sets visibility, marks onboarded, and lands on the profile" do
    user = users(:one)
    user.update!(handle: "olive")
    sign_in_as user

    patch welcome_finish_path, params: { public: true }

    assert_redirected_to "/olive"
    assert user.reload.onboarded?
    assert user.public?
    assert_equal true, flash[:welcome]
  end

  test "skipping every category still completes, private by default" do
    user = users(:one)
    user.update!(handle: "olive")
    sign_in_as user

    patch welcome_finish_path

    assert_redirected_to "/olive"
    assert user.reload.onboarded?
    assert_not user.public?
    assert_empty user.entries
  end

  test "finishing toward agents lands on the connect page" do
    user = users(:one)
    user.update!(handle: "olive")
    sign_in_as user

    patch welcome_finish_path, params: { next: "agents" }

    assert_redirected_to "/agents"
    assert user.reload.onboarded?
  end

  test "finishing without a handle goes back to the claim step" do
    sign_in_as users(:one)

    patch welcome_finish_path

    assert_redirected_to welcome_path(step: "handle")
    assert_not users(:one).reload.onboarded?
  end

  test "an onboarded member visiting /welcome goes to their profile" do
    sign_in_as users(:every_ana)

    get welcome_path

    assert_redirected_to "/ana"
  end
end
