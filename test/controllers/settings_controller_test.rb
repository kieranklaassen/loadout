require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @cy = users(:every_cy)
    sign_in_as @cy
  end

  test "renders the account settings" do
    get settings_path

    assert_response :success
    assert_inertia_component "settings/show"
    assert_equal({ handle: "cy", bio: "", public: false, email: "cy@every.to", every_member: true }, inertia.props[:account].symbolize_keys)
  end

  test "the handle change takes effect and the old handle 404s" do
    patch settings_path, params: { handle: "cyrus" }

    assert_redirected_to settings_path
    assert_equal "cyrus", @cy.reload.handle
    assert_equal "Your profile now lives at loadout.every.to/cyrus.", flash[:notice]

    get "/cy"
    assert_response :not_found
  end

  test "a taken or reserved handle is rejected with a message" do
    patch settings_path, params: { handle: "ana" }
    follow_redirect!
    assert_equal "loadout.every.to/ana is taken.", inertia.props[:errors][:handle]

    patch settings_path, params: { handle: "settings" }
    follow_redirect!
    assert_equal "loadout.every.to/settings is reserved.", inertia.props[:errors][:handle]
    assert_equal "cy", @cy.reload.handle
  end

  test "updates the bio and rejects one over 160 characters" do
    patch settings_path, params: { bio: "Ships  video tools." }
    assert_equal "Ships video tools.", @cy.reload.bio

    patch settings_path, params: { bio: "a" * 161 }
    follow_redirect!
    assert_match(/too long/, inertia.props[:errors][:bio])
    assert_equal "Ships video tools.", @cy.reload.bio
  end

  test "toggles visibility" do
    patch settings_path, params: { public: true }

    assert @cy.reload.public?
    assert_equal "Your profile is public.", flash[:notice]

    patch settings_path, params: { public: false }
    assert_not @cy.reload.public?
  end

  test "deleting the account removes the user, entries and changes and signs out" do
    Loadouts::Update.call(user: @cy, operations: [ { op: "add", category: "video", tool: "runway" } ], source: "web")
    assert @cy.entry_changes.any?

    delete settings_path, params: { confirmation: "cy" }

    assert_redirected_to root_path
    assert_not User.exists?(@cy.id)
    assert_not Entry.exists?(user_id: @cy.id)
    assert_not EntryChange.exists?(user_id: @cy.id)
    assert_not Session.exists?(user_id: @cy.id)

    get edit_loadout_path
    assert_redirected_to new_session_path
  end

  test "deleting needs the typed confirmation" do
    delete settings_path, params: { confirmation: "nope" }

    assert User.exists?(@cy.id)
    follow_redirect!
    assert_equal "Type cy to confirm.", inertia.props[:errors][:confirmation]
  end
end
