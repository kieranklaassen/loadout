require "test_helper"

# Props every Inertia page receives from InertiaController.
class SharedPropsTest < ActionDispatch::IntegrationTest
  teardown { Rails.configuration.x.public_base_url = nil }

  test "current_user carries visibility and whether the provider verified the email" do
    dee = users(:every_dee)
    sign_in_as dee

    get agents_path

    assert_equal(
      { id: dee.id, name: "Dee Every", handle: "dee", avatar_url: nil, every_member: true, admin: false, visibility: "team", email_verified: true, onboarded: true },
      inertia.props[:current_user].symbolize_keys
    )
  end

  test "an unverified Every address is signed in but not a team member" do
    sign_in_as users(:every_fay)

    get agents_path

    assert_equal [ false, false, "link" ], inertia.props[:current_user].values_at("every_member", "email_verified", "visibility")
  end

  test "every page gets the display host, from configuration" do
    get new_session_path
    assert_equal "loadout.every.to", inertia.props[:public_host]

    Rails.configuration.x.public_base_url = "https://loadout.example.test"
    get new_session_path
    assert_equal "loadout.example.test", inertia.props[:public_host]
  end
end
