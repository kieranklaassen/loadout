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

    patch admin_catalog_item_path(item, kind: "tool"), params: { item: { status: "approved", name: "Hedra", maker: "Hedra", hue: 270, monogram: "He" } }

    assert_redirected_to admin_catalog_items_path
    item.reload
    assert item.approved?
    assert_equal [ "Hedra", "Hedra", 270, "He" ], [ item.name, item.maker, item.hue, item.monogram ]
    assert_includes Tool.pickable, item
  end

  test "an invalid rename comes back with errors" do
    sign_in_as @admin

    patch admin_catalog_item_path(tools(:cursor), kind: "tool"), params: { item: { hue: 999 } }

    assert_redirected_to admin_catalog_items_path
    assert_equal 220, tools(:cursor).reload.hue
  end

  test "hiding removes an item from pickers but keeps it on existing entries" do
    sign_in_as @admin

    patch admin_catalog_item_path(tools(:cursor), kind: "tool"), params: { item: { status: "hidden" } }

    assert_not_includes Tool.pickable, tools(:cursor)
    assert_equal tools(:cursor), entries(:ana_cursor).reload.tool
  end

  test "merging repoints entries and history, then deletes the pending item" do
    suggested = Tool.resolve_or_suggest!("Claude-Code CLI", user: @member)
    Loadouts::Update.call(user: @member, operations: [ { op: "add", category: "coding", tool: suggested.name } ], source: "web")
    sign_in_as @admin

    post merge_admin_catalog_item_path(suggested, kind: "tool"), params: { target_id: tools(:claude_code).id }

    assert_redirected_to admin_catalog_items_path
    assert_not Tool.exists?(suggested.id)
    assert @member.entries.exists?(tool: tools(:claude_code), ai_model: nil)
    assert_equal [ tools(:claude_code).id ], @member.entry_changes.where(action: "added").pluck(:tool_id).uniq
  end

  test "merging drops an entry that would collide with one already on the target" do
    suggested = AiModel.resolve_or_suggest!("Opus Five", user: @member)
    Loadouts::Update.call(user: @member, operations: [ { op: "add", category: "coding", tool: "cursor", model: suggested.name, note: "Fast." } ], source: "web")
    sign_in_as @admin

    assert_difference -> { Entry.count }, -1 do
      post merge_admin_catalog_item_path(suggested, kind: "model"), params: { target_id: ai_models(:opus_5).id }
    end

    assert_not AiModel.exists?(suggested.id)
    kept = entries(:cy_cursor).reload
    assert_equal ai_models(:opus_5), kept.ai_model
    assert kept.primary
    assert_equal "Fast.", kept.note
    assert_equal 0, EntryChange.where(ai_model_id: suggested.id).count
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
