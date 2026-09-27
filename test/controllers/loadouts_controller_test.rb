require "test_helper"

class LoadoutsControllerTest < ActionDispatch::IntegrationTest
  EDITOR = "http://www.example.com/loadout/edit".freeze
  BACK = { "Referer" => EDITOR }.freeze

  setup do
    @ana = users(:every_ana)
    sign_in_as @ana
  end

  def patch_operations(*operations, headers: BACK)
    patch loadout_path, params: { operations: }, headers:, as: :json
  end

  def inertia_catalog_tools
    get edit_loadout_path
    inertia.props[:catalog][:tools]
  end

  def inertia_errors_after_redirect
    follow_redirect!
    inertia.props[:errors]
  end

  def fill_coding
    Loadouts::Update.call(user: @ana, operations: [ { op: "set_pick", category: "coding", rank: 3, tool: Tool.create!(name: "Windsurf", status: "approved").slug } ], source: "web")
  end

  test "the editor renders the owner's kinds with picks and suggestions" do
    get edit_loadout_path

    assert_response :success
    assert_inertia_component "loadout/edit"
    kinds = inertia.props[:kinds]
    assert_equal %w[coding knowledge-work video], kinds.map { |kind| kind[:category][:slug] }
    coding, _knowledge_work, video = kinds
    assert_equal %w[cursor claude-code], coding[:picks].map { |pick| pick[:tool][:slug] }
    assert_equal [ 1, "claude-opus-5-5", "1m", "high" ], [ coding[:picks].first[:rank], coding[:picks].first[:model][:slug], coding[:picks].first[:context], coding[:picks].first[:effort] ]
    assert_equal [ "runway", 1, 1, "WebMCP" ], video[:suggestions].sole.then { |s| [ s[:tool][:slug], s[:slot_hint], s[:target_rank], s[:suggested_by] ] }
    assert_equal 1, video[:to_confirm]
  end

  test "the editor also gets the catalog, the choices, the open kind, who can see the page and what the team uses" do
    get edit_loadout_path(kind: "video")

    props = inertia.props
    assert_equal %w[catalog enums kinds selected_kind team_top visibility], (props.keys & %w[kinds catalog enums selected_kind visibility team_top]).sort
    assert_equal "video", props[:selected_kind]
    assert_equal "link", props[:visibility]
    assert_equal [ %w[200k 1m], %w[low medium high] ], props[:enums].values_at(:context, :effort)
    assert_equal [ Entry::CONTEXTS, Entry::EFFORTS ], props[:enums].values_at(:context, :effort)
    assert_equal %w[cursor claude-code claude runway], props[:catalog][:tools].map { |tool| tool[:slug] }
    assert_equal [ "claude-opus-5-5", [ "coding", "knowledge-work" ] ], props[:catalog][:models].first.values_at(:slug, :suggested_for)

    coding = props[:team_top]["coding"]
    assert_equal [ [ "claude-code", 2 ], [ "cursor", 1 ] ], coding[:tools].map { |tool| [ tool[:item][:slug], tool[:yours_rank] ] }
    assert_equal [ [ "claude-opus-5-5", 2, 1, true ], [ "gpt-6-astra", 1, nil, false ] ], coding[:models].map { |model| [ model[:item][:slug], model[:count][:n], model[:yours_rank], model[:launched] ] }
    assert_equal [ 2, 2 ], coding[:tools].first[:count].values_at(:n, :of)
  end

  test "the open kind defaults to the first with room and ignores an unknown one" do
    get edit_loadout_path
    assert_equal "coding", inertia.props[:selected_kind]

    get edit_loadout_path(kind: "made-up")
    assert_equal "coding", inertia.props[:selected_kind]
  end

  test "a member who shares with nobody sees their own picks counted and is told only they can see them" do
    sign_in_as users(:every_cy)

    get edit_loadout_path

    assert_equal "only_me", inertia.props[:visibility]
    cursor = inertia.props[:team_top]["coding"][:tools].find { |tool| tool[:item][:slug] == "cursor" }
    assert_equal [ 3, 3, 1 ], [ cursor[:count][:n], cursor[:count][:of], cursor[:yours_rank] ]
  end

  test "setting a pick persists rank, context and effort, drops unknown fields, and redirects back" do
    patch_operations({ op: "set_pick", category: "video", rank: 1, tool: "runway", model: nil, context: "1m", effort: "low", primary: true, note: "old field" })

    assert_redirected_to EDITOR
    entry = @ana.entries.find_by!(category: categories(:video))
    assert_equal [ 1, tools(:runway), nil, "1m", "low" ], [ entry.rank, entry.tool, entry.ai_model, entry.context, entry.effort ]
    assert_equal "web", @ana.entry_changes.order(:id).last.source
    assert_equal "Saved.", flash[:notice]
    assert_replays_to_entries @ana
  end

  test "a null model clears the model and leaves the other fields alone" do
    patch_operations({ op: "set_pick", category: "coding", rank: 1, model: nil })

    entry = @ana.entries.find_by!(category: categories(:coding), rank: 1)
    assert_equal [ tools(:cursor), nil, "1m", "high" ], [ entry.tool, entry.ai_model, entry.context, entry.effort ]
  end

  test "moving a pick swaps it with its neighbour and removing one closes the gap" do
    patch_operations({ op: "move_pick", category: "coding", rank: 1, direction: "down" })
    assert_equal %w[claude-code cursor], @ana.entries.where(category: categories(:coding)).order(:rank).map { |entry| entry.tool.slug }

    patch_operations({ op: "remove_pick", category: "coding", rank: 1 })
    assert_equal [ [ 1, "cursor" ] ], @ana.entries.where(category: categories(:coding)).map { |entry| [ entry.rank, entry.tool.slug ] }
    assert_replays_to_entries @ana
  end

  test "an invalid operation comes back as an alert and writes nothing" do
    assert_no_difference -> { EntryChange.count } do
      patch_operations({ op: "remove_pick", category: "video", rank: 1 })
    end

    assert_redirected_to EDITOR
    assert_match(/Nothing is ranked 1st for video/, flash[:alert])
  end

  test "no operations saves nothing" do
    patch loadout_path, params: {}, as: :json

    assert_equal "Nothing to save.", flash[:notice]
  end

  test "the slot endpoint takes slot operations only, so it can neither confirm nor suggest" do
    suggestion = pick_suggestions(:ana_runway)

    assert_no_difference [ "Entry.count", "PickSuggestion.count", "EntryChange.count" ] do
      patch_operations({ op: "confirm", category: "video", suggestion_id: suggestion.id })
      assert_equal "Use one of: set_pick, remove_pick, move_pick.", flash[:alert]
      patch_operations({ op: "dismiss", suggestion_id: suggestion.id })
      assert flash[:alert].present?
      patch_operations({ op: "suggest", category: "video", tool: "runway" })
      assert flash[:alert].present?
    end
    assert_equal "open", suggestion.reload.status
  end

  test "confirming places the suggestion and redirects back" do
    suggestion = pick_suggestions(:ana_runway)

    post confirm_loadout_suggestion_path(suggestion), headers: BACK, as: :json

    assert_redirected_to EDITOR
    assert_equal "Confirmed.", flash[:notice]
    entry = @ana.entries.find_by!(category: categories(:video))
    assert_equal [ 1, tools(:runway) ], [ entry.rank, entry.tool ]
    assert_equal "confirmed", suggestion.reload.status
    assert_replays_to_entries @ana
  end

  test "confirming with the slot to replace and the snapshot shown replaces that pick" do
    fill_coding
    suggestion = Loadouts::Update.call(user: @ana, operations: [ { op: "suggest", category: "coding", tool: "runway" } ], source: "webmcp").suggestions.sole

    post confirm_loadout_suggestion_path(suggestion), params: { rank: 2, expected: { tool: "claude-code", model: nil } }, headers: BACK, as: :json

    assert_equal "Confirmed.", flash[:notice]
    assert_equal %w[cursor runway windsurf], @ana.entries.where(category: categories(:coding)).order(:rank).map { |entry| entry.tool.slug }
  end

  test "a stale snapshot comes back as This changed, review it and writes nothing" do
    fill_coding
    suggestion = Loadouts::Update.call(user: @ana, operations: [ { op: "suggest", category: "coding", tool: "runway" } ], source: "webmcp").suggestions.sole

    assert_no_difference -> { Entry.count } do
      post confirm_loadout_suggestion_path(suggestion), params: { rank: 2, expected: { tool: "cursor", model: nil } }, headers: BACK, as: :json
    end

    assert_equal "This changed, review it.", flash[:alert]
    assert_equal "open", suggestion.reload.status
  end

  test "a full kind with no slot chosen asks which pick to replace" do
    fill_coding
    suggestion = Loadouts::Update.call(user: @ana, operations: [ { op: "suggest", category: "coding", tool: "runway" } ], source: "webmcp").suggestions.sole

    post confirm_loadout_suggestion_path(suggestion), headers: BACK, as: :json

    assert_equal "All three slots are taken. Choose which pick to replace.", flash[:alert]
  end

  test "dismissing closes the suggestion and keeps the entries" do
    suggestion = pick_suggestions(:ana_runway)

    delete loadout_suggestion_path(suggestion), headers: BACK, as: :json

    assert_redirected_to EDITOR
    assert_equal "dismissed", suggestion.reload.status
    assert_not @ana.entries.exists?(category: categories(:video))
    assert_equal "dismissed", @ana.entry_changes.order(:id).last.action
  end

  test "another member's suggestion can be neither confirmed nor dismissed" do
    foreign = Loadouts::Update.call(user: users(:every_dee), operations: [ { op: "suggest", category: "video", tool: "runway" } ], source: "mcp", client_name: "Claude", oauth_client_id: 3).suggestions.sole

    post confirm_loadout_suggestion_path(foreign), headers: BACK, as: :json
    assert flash[:alert].present?
    delete loadout_suggestion_path(foreign), headers: BACK, as: :json
    assert flash[:alert].present?

    assert_equal "open", foreign.reload.status
    assert_not users(:every_dee).entries.exists?(category: categories(:video))
  end

  test "nothing confirms on a GET" do
    suggestion = pick_suggestions(:ana_runway)

    get "/loadout/suggestions/#{suggestion.id}/confirm"
    assert_response :not_found
    get "/loadout/suggestions/#{suggestion.id}"
    assert_response :not_found

    assert_equal "open", suggestion.reload.status
  end

  test "adding a tool the catalog lacks creates a pending one for the member, offered to them and to nobody else" do
    assert_difference -> { Tool.pending.count }, 1 do
      post loadout_catalog_items_path, params: { kind: "tool", name: "  Zed  " }, headers: BACK, as: :json
    end

    assert_redirected_to EDITOR
    zed = Tool.find_by!(slug: "zed")
    assert_equal [ "Zed", "pending", @ana ], [ zed.name, zed.status, zed.created_by ]
    assert_match(/Added Zed/, flash[:notice])
    assert_equal [ true ], inertia_catalog_tools.select { |tool| tool[:slug] == "zed" }.pluck(:pending)
    assert_not @ana.entries.exists?(tool: zed), "adding an item never picks it"

    sign_in_as users(:every_dee)
    get edit_loadout_path
    assert_not_includes inertia.props[:catalog][:tools].pluck(:slug), "zed"
  end

  test "adding a model creates a pending model" do
    assert_difference -> { AiModel.pending.count }, 1 do
      post loadout_catalog_items_path, params: { kind: "model", name: "Beta Model" }, headers: BACK, as: :json
    end

    assert_equal [ "Beta Model", @ana ], AiModel.pending.sole.then { |model| [ model.name, model.created_by ] }
  end

  test "an item the member can already pick is not added again" do
    assert_no_difference [ "Tool.count", "AiModel.count" ] do
      post loadout_catalog_items_path, params: { kind: "tool", name: "cursor" }, headers: BACK, as: :json
      assert_equal "Already in the list.", follow_redirect!.then { inertia.props[:errors][:name] }
      post loadout_catalog_items_path, params: { kind: "model", name: "CLAUDE OPUS 5.5" }, headers: BACK, as: :json
      assert_equal "Already in the list.", follow_redirect!.then { inertia.props[:errors][:name] }
    end
  end

  test "a name that is with the admins already, or was hidden, is not added" do
    Tool.create!(name: "Windsurf", status: "pending", created_by: users(:every_dee))

    assert_no_difference "Tool.count" do
      post loadout_catalog_items_path, params: { kind: "tool", name: "Windsurf" }, headers: BACK, as: :json
      assert_match(/with the admins/, follow_redirect!.then { inertia.props[:errors][:name] })
      post loadout_catalog_items_path, params: { kind: "tool", name: "Old Thing" }, headers: BACK, as: :json
      assert_match(/with the admins/, follow_redirect!.then { inertia.props[:errors][:name] })
    end
  end

  test "a name must be two to sixty characters and the kind a tool or a model" do
    assert_no_difference [ "Tool.count", "AiModel.count" ] do
      [ [ "tool", "Z" ], [ "tool", " " ], [ "model", "x" * 61 ], [ "prompt", "Zed" ], [ nil, "Zed" ] ].each do |kind, name|
        post loadout_catalog_items_path, params: { kind:, name: }, headers: BACK, as: :json
        assert_redirected_to EDITOR
        assert inertia_errors_after_redirect[:name].present?, "#{kind.inspect} #{name.inspect} was accepted"
      end
    end

    post loadout_catalog_items_path, params: { kind: "tool", name: "x" * 60 }, headers: BACK, as: :json
    assert Tool.pending.exists?(created_by: @ana)
  end

  test "signed-out visitors cannot add an item" do
    sign_out

    assert_no_difference "Tool.count" do
      post loadout_catalog_items_path, params: { kind: "tool", name: "Zed" }, as: :json
    end
    assert_redirected_to new_session_path
  end

  test "signed-out visitors are sent to sign in" do
    suggestion = pick_suggestions(:ana_runway)
    sign_out

    get edit_loadout_path
    assert_redirected_to new_session_path
    patch loadout_path, params: { operations: [] }, as: :json
    assert_redirected_to new_session_path
    post confirm_loadout_suggestion_path(suggestion), as: :json
    assert_redirected_to new_session_path
    delete loadout_suggestion_path(suggestion), as: :json
    assert_redirected_to new_session_path

    assert_equal "open", suggestion.reload.status
  end
end
