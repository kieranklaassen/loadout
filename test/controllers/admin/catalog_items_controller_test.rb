require "test_helper"

class Admin::CatalogItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:every_ana)
    @admin.update!(admin: true)
    @member = users(:every_cy)
  end

  test "non-admins and signed-out visitors get a 404" do
    get admin_catalog_items_path
    assert_response :not_found

    sign_in_as @member
    get admin_catalog_items_path
    assert_response :not_found

    patch admin_catalog_item_path(tools(:cursor), kind: "tool"), params: { item: { status: "hidden" } }
    assert_response :not_found
    assert tools(:cursor).reload.approved?
  end

  test "the Flipper dashboard is a 404 for non-admins and open to admins" do
    get "/admin/flipper"
    assert_response :not_found

    sign_in_as @member
    get "/admin/flipper"
    assert_response :not_found

    sign_in_as @admin
    get "/admin/flipper/features"
    assert_response :success
  end

  test "an admin sees pending tools and models first" do
    pending_tool = Tool.resolve_or_suggest!("Hedra Studio", user: @member)
    pending_model = AiModel.resolve_or_suggest!("Mystery 3", user: @member)
    sign_in_as @admin

    get admin_catalog_items_path

    assert_response :success
    assert_inertia_component "admin/catalog"
    assert_equal [ [ "tool", pending_tool.id ], [ "model", pending_model.id ] ], inertia.props[:pending].map { |item| [ item[:kind], item[:id] ] }
    assert_equal "Cy Every", inertia.props[:pending].first[:created_by][:name]
    assert_equal 2, inertia.props[:counts][:pending]
  end

  test "item props carry no usage counts, and only pending items show who added them" do
    hedra = Tool.resolve_or_suggest!("Hedra Studio", user: @member)
    Tool.create!(name: "Member Made", status: "approved", created_by: @member)
    sign_in_as @admin

    get admin_catalog_items_path

    everything = inertia.props[:pending] + inertia.props[:items]
    assert everything.none? { |item| item.key?(:people) }
    by_slug = inertia.props[:items].index_by { |item| item[:slug] }
    assert_equal "Cy Every", by_slug.fetch(hedra.slug).dig(:created_by, :name)
    assert_nil by_slug.fetch("member-made")[:created_by]
    assert_equal %w[id name], inertia.props[:merge_targets][:tool].first.keys
  end

  test "models carry their release date and Vibe Check link, tools carry neither" do
    sign_in_as @admin

    get admin_catalog_items_path

    by_slug = inertia.props[:items].index_by { |item| item[:slug] }
    opus = by_slug.fetch("claude-opus-5-5")
    assert_equal [ ai_models(:opus_5_5).released_on.iso8601, "https://checks.every.to/vibe-checks/claude-opus-5-5" ], opus.values_at(:released_on, :vibe_check_url)
    assert_equal [ nil, nil ], by_slug.fetch("gpt-6-astra").values_at(:released_on, :vibe_check_url)
    assert_not by_slug.fetch("cursor").key?(:released_on)
  end

  test "filters narrow the full list" do
    sign_in_as @admin

    get admin_catalog_items_path(kind: "tool", status: "hidden")

    assert_equal [ "old-thing" ], inertia.props[:items].pluck(:slug)

    get admin_catalog_items_path(q: "opus")
    assert_equal %w[claude-opus-5-5 claude-opus-5], inertia.props[:items].pluck(:slug)
  end

  test "approving and renaming a pending item" do
    item = Tool.resolve_or_suggest!("hedra", user: @member)
    sign_in_as @admin

    patch admin_catalog_item_path(item, kind: "tool"), params: { item: { status: "approved", name: "Hedra", maker: "Hedra" } }

    assert_redirected_to admin_catalog_items_path
    item.reload
    assert item.approved?
    assert_equal [ "Hedra", "Hedra" ], [ item.name, item.maker ]
    assert_not_nil item.admin_edited_at
    assert_includes Tool.pickable, item
  end

  test "an invalid rename comes back with errors" do
    sign_in_as @admin

    patch admin_catalog_item_path(tools(:cursor), kind: "tool"), params: { item: { name: "" } }

    assert_redirected_to admin_catalog_items_path
    follow_redirect!
    assert_match(/can't be blank/, inertia.props[:errors][:name])
    assert_equal "Cursor", tools(:cursor).reload.name
  end

  test "an admin sets a model's release date and Vibe Check link, which makes it a launch and freezes it against sync" do
    model = ai_models(:gpt_6)
    sign_in_as @admin

    patch admin_catalog_item_path(model, kind: "model"), params: { item: { released_on: "2026-09-04", vibe_check_url: "https://checks.every.to/vibe-checks/gpt-6" } }

    assert_redirected_to admin_catalog_items_path
    model.reload
    assert_equal [ Date.new(2026, 9, 4), "https://checks.every.to/vibe-checks/gpt-6" ], [ model.released_on, model.vibe_check_url ]
    assert_not_nil model.admin_edited_at
    assert_includes AiModel.launched, model
  end

  test "the Vibe Check link must be https on an allowed host, and the error says so" do
    model = ai_models(:gpt_6)
    sign_in_as @admin

    [ "http://checks.every.to/vibe-checks/gpt-6", "https://evil.example/vibe-checks/gpt-6", "https://checks.every.to.evil.example/x" ].each do |url|
      patch admin_catalog_item_path(model, kind: "model"), params: { item: { released_on: "2026-09-04", vibe_check_url: url } }
      follow_redirect!

      assert_match(/must be an https link on every\.to or checks\.every\.to/, inertia.props[:errors][:vibe_check_url], url)
      model.reload
      assert_equal [ nil, nil, nil ], [ model.released_on, model.vibe_check_url, model.admin_edited_at ], url
    end
  end

  test "clearing the Vibe Check link takes the model out of the launches" do
    model = ai_models(:opus_5_5)
    assert_includes AiModel.launched, model
    sign_in_as @admin

    patch admin_catalog_item_path(model, kind: "model"), params: { item: { vibe_check_url: "" } }

    assert_nil model.reload.vibe_check_url
    assert_not_includes AiModel.launched, model
  end

  test "launch fields are ignored for tools" do
    sign_in_as @admin

    patch admin_catalog_item_path(tools(:cursor), kind: "tool"), params: { item: { released_on: "2026-09-04", vibe_check_url: "https://checks.every.to/x", name: "Cursor IDE" } }

    assert_redirected_to admin_catalog_items_path
    assert_equal "Cursor IDE", tools(:cursor).reload.name
  end

  test "hiding removes an item from pickers but keeps it on existing entries" do
    sign_in_as @admin

    patch admin_catalog_item_path(tools(:cursor), kind: "tool"), params: { item: { status: "hidden" } }

    assert_not_includes Tool.pickable, tools(:cursor)
    assert_equal tools(:cursor), entries(:ana_cursor).reload.tool
    assert_nil tools(:cursor).reload.admin_edited_at, "hiding is not an edit that sync has to respect"
  end

  test "merging repoints picks and history, then deletes the pending item" do
    suggested = Tool.resolve_or_suggest!("Claude-Code CLI", user: @member)
    Toolbox::Update.call(user: @member, operations: [ { op: "set_pick", category: "coding", rank: 2, tool: suggested.slug } ], source: "web")
    sign_in_as @admin

    post merge_admin_catalog_item_path(suggested, kind: "tool"), params: { target_id: tools(:claude_code).id }

    assert_redirected_to admin_catalog_items_path
    assert_not Tool.exists?(suggested.id)
    assert_equal [ [ 1, tools(:cursor) ], [ 2, tools(:claude_code) ] ], @member.entries.order(:rank).map { |entry| [ entry.rank, entry.tool ] }
    assert_equal [ tools(:claude_code).id ], @member.entry_changes.where(action: "set", rank: 2).pluck(:tool_id)
    assert_replays_to_entries @member
  end

  test "merging keeps the higher pick when a member ranked both tools" do
    suggested = Tool.resolve_or_suggest!("Claude-Code CLI", user: @member)
    Toolbox::Update.call(user: @member, source: "web", operations: [
      { op: "set_pick", category: "coding", rank: 2, tool: suggested.slug },
      { op: "set_pick", category: "coding", rank: 3, tool: tools(:claude_code).slug }
    ])
    sign_in_as @admin

    assert_difference -> { Entry.count }, -1 do
      post merge_admin_catalog_item_path(suggested, kind: "tool"), params: { target_id: tools(:claude_code).id }
    end

    assert_not Tool.exists?(suggested.id)
    assert_equal [ [ 1, tools(:cursor) ], [ 2, tools(:claude_code) ] ], @member.entries.order(:rank).map { |entry| [ entry.rank, entry.tool ] }
    assert_equal [ [ "removed", 3 ] ], @member.entry_changes.where(source: "system").map { |change| [ change.action, change.rank ] }
    assert_replays_to_entries @member
  end

  test "merging a model repoints the picks that use it and keeps their ranks" do
    suggested = AiModel.resolve_or_suggest!("Opus Five", user: @member)
    Toolbox::Update.call(user: @member, operations: [ { op: "set_pick", category: "coding", rank: 1, model: suggested.slug } ], source: "web")
    sign_in_as @admin

    assert_no_difference -> { Entry.count } do
      post merge_admin_catalog_item_path(suggested, kind: "model"), params: { target_id: ai_models(:opus_5_5).id }
    end

    assert_not AiModel.exists?(suggested.id)
    kept = entries(:cy_cursor).reload
    assert_equal [ 1, tools(:cursor), ai_models(:opus_5_5) ], [ kept.rank, kept.tool, kept.ai_model ]
    assert_equal 0, EntryChange.where(ai_model_id: suggested.id).count
    assert_replays_to_entries @member
  end

  test "merging across kinds or into itself is refused" do
    item = Tool.resolve_or_suggest!("Solo", user: @member)
    sign_in_as @admin

    post merge_admin_catalog_item_path(item, kind: "tool"), params: { target_id: item.id }

    assert Tool.exists?(item.id)
    assert_equal "An item can't be merged into itself.", flash[:alert]
  end

  test "deleting an item in use is refused, an unused one goes" do
    unused = Tool.resolve_or_suggest!("Typo Tool", user: @member)
    sign_in_as @admin

    delete admin_catalog_item_path(tools(:cursor), kind: "tool")
    assert Tool.exists?(tools(:cursor).id)

    delete admin_catalog_item_path(unused, kind: "tool")
    assert_not Tool.exists?(unused.id)
  end
end

class Admin::CatalogItemsGuardTest < ActionController::TestCase
  tests Admin::CatalogItemsController

  test "the controller guard 404s a non-admin even past the route constraint" do
    session = users(:every_cy).sessions.create!
    cookies.signed[:session_id] = session.id

    get :index

    assert_response :not_found
  end

  test "the guard lets an admin through" do
    users(:every_ana).update!(admin: true)
    cookies.signed[:session_id] = users(:every_ana).sessions.create!.id

    get :index

    assert_response :success
  end
end
