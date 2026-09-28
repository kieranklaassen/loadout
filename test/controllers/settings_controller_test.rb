require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @cy = users(:every_cy)
    sign_in_as @cy
  end

  test "renders the account settings and the connected agents" do
    client = OauthClient.create!(client_name: "Cursor", redirect_uris: [ McpOauthHelper::LOOPBACK_REDIRECT ])
    OauthGrant.issue!(user: @cy, client:, resource: "http://www.example.com/mcp", scope: "loadout")
    OauthGrant.issue!(user: users(:every_ana), client: OauthClient.create!(client_name: "Codex", redirect_uris: [ McpOauthHelper::LOOPBACK_REDIRECT ]),
      resource: "http://www.example.com/mcp", scope: "loadout")

    get settings_path

    assert_response :success
    assert_inertia_component "settings/show"
    assert_equal({ name: "Cy Every", handle: "cy", bio: "", visibility: "only_me" }, inertia.props[:account].symbolize_keys)
    assert_equal [ "Cursor" ], inertia.props[:agents].map { |agent| agent[:name] }
    assert_equal client.client_id, inertia.props[:agents].first[:id]
    assert_nil inertia.props[:agents].first[:last_used_at]
  end

  test "the handle change takes effect and the old handle 404s" do
    patch settings_path, params: { handle: "cyrus" }

    assert_redirected_to settings_path
    assert_equal "cyrus", @cy.reload.handle
    assert_equal "Your profile now lives at #{LoadoutHost::DEFAULT_HOST}/cyrus.", flash[:notice]

    get "/cy"
    assert_response :not_found
  end

  test "a taken or reserved handle is rejected with a message" do
    patch settings_path, params: { handle: "ana" }
    follow_redirect!
    assert_equal "#{LoadoutHost::DEFAULT_HOST}/ana is taken.", inertia.props[:errors][:handle]

    patch settings_path, params: { handle: "settings" }
    follow_redirect!
    assert_equal "#{LoadoutHost::DEFAULT_HOST}/settings is reserved.", inertia.props[:errors][:handle]
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

  test "handle, bio and visibility save together in one request" do
    patch settings_path, params: { handle: "cyrus", bio: "Video tools.", visibility: "team" }

    assert_redirected_to settings_path
    @cy.reload
    assert_equal [ "cyrus", "Video tools.", "team" ], [ @cy.handle, @cy.bio, @cy.visibility ]
  end

  test "sharing with the team opens a team period, and widening to the link closes it and opens a link period" do
    assert_empty open_levels

    patch settings_path, params: { visibility: "team" }
    assert_equal "team", @cy.reload.visibility
    assert_equal [ "team" ], open_levels

    patch settings_path, params: { visibility: "link" }
    assert_equal "link", @cy.reload.visibility
    assert_equal [ "link" ], open_levels
    assert_equal 3, @cy.visibility_periods.count, "the fixture's past team period, the team period just closed, and the open link period"
    assert_empty @cy.visibility_periods.where(level: "team", ends_at: nil)
  end

  test "going back to only me closes the open period and opens none" do
    patch settings_path, params: { visibility: "link" }
    patch settings_path, params: { visibility: "only_me" }

    assert_equal "only_me", @cy.reload.visibility
    assert_empty open_levels
    assert_equal 2, @cy.visibility_periods.count
    assert @cy.visibility_periods.all?(&:ends_at)
  end

  test "an unknown visibility is rejected and neither the level nor the periods change" do
    patch settings_path, params: { visibility: "public" }
    follow_redirect!

    assert inertia.props[:errors][:visibility].present?
    assert_equal "only_me", @cy.reload.visibility
    assert_equal 1, @cy.visibility_periods.count
  end

  test "a member without a handle cannot share, and neither the level nor the periods change" do
    sign_in_as users(:one)

    patch settings_path, params: { visibility: "team" }

    assert_redirected_to settings_path
    assert_equal "only_me", users(:one).reload.visibility
    assert_empty users(:one).visibility_periods

    follow_redirect! # settings sends a member who has not claimed a link to /welcome, which shows the refusal
    follow_redirect!
    assert_inertia_component "onboarding/show"
    assert_equal "Visibility needs a claimed link before you share your page", inertia.props[:errors][:visibility]
  end

  test "the retired public flag is not a setting any more" do
    patch settings_path, params: { public: true }

    assert_equal "only_me", @cy.reload.visibility
  end

  test "deleting the account removes the user, entries, changes, suggestions and periods and signs out" do
    Loadouts::Update.call(user: @cy, operations: [ { op: "set_pick", category: "video", rank: 1, tool: "runway" } ], source: "web")
    Loadouts::Update.call(user: @cy, operations: [ { op: "suggest", category: "coding", tool: "claude-code" } ], source: "webmcp", client_name: "WebMCP")
    patch settings_path, params: { visibility: "team" }
    assert @cy.entry_changes.any?
    assert @cy.pick_suggestions.any?
    assert @cy.visibility_periods.any?

    delete settings_path, params: { confirmation: "cy" }

    assert_redirected_to root_path
    assert_not User.exists?(@cy.id)
    assert_not Entry.exists?(user_id: @cy.id)
    assert_not EntryChange.exists?(user_id: @cy.id)
    assert_not PickSuggestion.exists?(user_id: @cy.id)
    assert_not VisibilityPeriod.exists?(user_id: @cy.id)
    assert_not Session.exists?(user_id: @cy.id)

    get edit_loadout_path
    assert_redirected_to new_session_path
  end

  test "deleting needs the exact typed handle" do
    delete settings_path, params: { confirmation: "nope" }

    assert User.exists?(@cy.id)
    follow_redirect!
    assert_equal "Type cy to confirm.", inertia.props[:errors][:confirmation]

    delete settings_path, params: { confirmation: "" }
    assert User.exists?(@cy.id)
  end

  private

  def open_levels
    @cy.visibility_periods.where(ends_at: nil).map(&:level)
  end
end
