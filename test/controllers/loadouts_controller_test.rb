require "test_helper"

class LoadoutsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @ana = users(:every_ana)
    sign_in_as @ana
  end

  test "the editor renders every category with suggestions and current picks" do
    get edit_loadout_path

    assert_response :success
    assert_inertia_component "loadout/edit"
    coding = inertia.props[:categories].find { |category| category[:slug] == "coding" }
    assert_equal %w[cursor claude-code], coding[:tool_slugs]
    assert_includes coding[:model_slugs], "claude-opus-5-5"
    assert_not_includes inertia.props[:catalog][:tools].pluck(:slug), "old-thing"
    pick = inertia.props[:picks][:coding].first
    assert_equal "cursor", pick[:tool][:slug]
    assert_equal "claude-opus-5-5", pick[:model][:slug]
    assert pick[:primary]
    assert_equal "My thinking partner.", inertia.props[:picks][:"knowledge-work"].first[:note]
  end

  test "replacing a category writes the diff through Loadouts::Update and redirects back" do
    patch loadout_path, params: {
      operations: [ { op: "replace_category", category: "coding", picks: [ { tool: "claude-code", primary: true, note: "Lives in my terminal" } ] } ]
    }, headers: { "Referer" => "http://www.example.com/loadout/edit" }, as: :json

    assert_redirected_to "http://www.example.com/loadout/edit"
    entry = @ana.entries.find_by!(category: categories(:coding))
    assert_equal tools(:claude_code), entry.tool
    assert_equal "Lives in my terminal", entry.note
    assert_equal [ "web" ], @ana.entry_changes.distinct.pluck(:source)
    assert_match(/Saved\. \d changes/, flash[:notice])
  end

  test "an empty pick list clears a category" do
    patch loadout_path, params: { operations: [ { op: "replace_category", category: "coding", picks: [] } ] }, as: :json

    assert_not @ana.entries.exists?(category: categories(:coding))
  end

  test "accepts generic operations, like the map's one-click add" do
    patch loadout_path, params: { operations: [ { op: "add", category: "video", tool: "runway" } ] },
      headers: { "Referer" => "http://www.example.com/map/video" }, as: :json

    assert_redirected_to "http://www.example.com/map/video"
    assert @ana.entries.exists?(category: categories(:video), tool: tools(:runway))
  end

  test "an invalid operation comes back as an alert and writes nothing" do
    assert_no_difference -> { EntryChange.count } do
      patch loadout_path, params: { operations: [ { op: "remove", category: "video", tool: "runway" } ] }, as: :json
    end

    assert_redirected_to edit_loadout_path
    assert_match(/not in your video loadout/, flash[:alert])
  end

  test "a note longer than 280 characters is rejected" do
    patch loadout_path, params: {
      operations: [ { op: "update_note", category: "coding", tool: "cursor", model: "claude-opus-5-5", note: "a" * 281 } ]
    }, as: :json

    assert_match(/Note is too long/, flash[:alert])
  end

  test "no operations saves nothing" do
    patch loadout_path, params: {}, as: :json

    assert_equal "Nothing to save.", flash[:notice]
  end

  test "signed-out visitors are sent to sign in" do
    sign_out

    get edit_loadout_path

    assert_redirected_to new_session_path
  end
end
