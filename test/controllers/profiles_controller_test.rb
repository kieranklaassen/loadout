require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @ana = users(:every_ana)
    @cy = users(:every_cy)
  end

  test "a public profile renders for a signed-out visitor" do
    get "/ana"

    assert_response :success
    assert_inertia_component "profiles/show"
    assert_inertia_props is_owner: false
    assert_equal "ana", inertia.props[:profile][:handle]
    assert inertia.props[:profile][:every_member]
    assert_equal %w[coding knowledge-work], inertia.props[:categories].map { |category| category[:slug] }
  end

  test "a private profile is a 404 for a signed-out visitor, like an unknown handle (AE1)" do
    get "/cy"
    assert_response :not_found

    get "/nobody-here"
    assert_response :not_found
  end

  test "a private profile is a 404 for another signed-in member" do
    sign_in_as @ana

    get "/cy"

    assert_response :not_found
  end

  test "the owner sees their private profile" do
    sign_in_as @cy

    get "/cy"

    assert_response :success
    assert_inertia_props is_owner: true
    assert_equal false, inertia.props[:profile][:public]
  end

  test "after the owner goes public, the profile and its card render (AE1)" do
    get "/cy"
    assert_response :not_found

    @cy.update!(public: true)

    get "/cy"
    assert_response :success
    get "/cy/og.png"
    assert_response :success
  end

  test "handles are case-sensitive lowercase and reserved paths still route elsewhere" do
    get "/up"
    assert_response :success

    get "/session/new"
    assert_response :success

    get "/Ana"
    assert_response :not_found
  end

  test "link preview meta tags describe a public profile" do
    get "/ana"

    assert_select "title", text: "Ana Every's AI loadout"
    assert_select "meta[property='og:title'][content=?]", "Ana Every's AI loadout"
    assert_select "meta[property='og:description'][content*=?]", "Cursor with Claude Opus 5.5 for coding"
    assert_select "meta[property='og:image'][content=?]", "http://www.example.com/ana/og.png?v=#{@ana.loadout_updated_at.to_i}"
    assert_select "meta[name='twitter:card'][content='summary_large_image']"
    assert_select "meta[name=robots]", count: 0
  end

  test "a private profile is noindex and does not point at its card" do
    sign_in_as @cy

    get "/cy"

    assert_select "meta[name=robots][content=noindex]"
    assert_select "meta[property='og:image'][content$='/og-default.png']"
  end

  test "recent changes tell the story of a model switch from an agent (AE2)" do
    Loadouts::Update.call(
      user: @ana,
      operations: [ { op: "replace_category", category: "coding", picks: [ { tool: "cursor", model: "claude-opus-5", primary: true } ] } ],
      source: "web"
    )
    result = Loadouts::Update.call(
      user: @ana,
      operations: [ { op: "replace_category", category: "coding", picks: [ { tool: "cursor", model: "claude-opus-5-5", primary: true } ] } ],
      source: "mcp", client_name: "Claude Code"
    )
    assert_equal [ [ "added", "Claude Opus 5.5" ], [ "removed", "Claude Opus 5" ] ],
      result.changes.reject { |change| change.action == "made_primary" }.map { |change| [ change.action, change.ai_model.name ] }.sort
    assert result.changes.all? { |change| change.source == "mcp" && change.client_name == "Claude Code" }

    get "/ana"

    latest = inertia.props[:recent_changes].first
    assert_equal "Switched coding model from Claude Opus 5 to Claude Opus 5.5 in Cursor", latest[:sentence]
    assert_equal "Claude Code", latest[:client_name]
    assert_operator inertia.props[:recent_changes].size, :<=, ProfilesController::RECENT_CHANGES
  end
end
