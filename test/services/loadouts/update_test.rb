require "test_helper"

class Loadouts::UpdateTest < ActiveSupport::TestCase
  setup { @user = users(:one) }

  def update(*operations, source: "web", client_name: nil, oauth_client_id: nil)
    Loadouts::Update.call(user: @user, operations:, source:, client_name:, oauth_client_id:)
  end

  def set_pick(rank, tool, category: "coding", **fields)
    { op: "set_pick", category:, rank:, tool:, **fields }
  end

  test "set_pick fills a slot, records a dated change with its source, and moves loadout_updated_at" do
    result = update(set_pick(1, "cursor", model: "claude-opus-5-5", context: "1m", effort: "high"))

    entry = @user.entries.sole
    assert_equal [ 1, tools(:cursor), ai_models(:opus_5_5), "1m", "high" ], [ entry.rank, entry.tool, entry.ai_model, entry.context, entry.effort ]
    change = result.changes.sole
    assert_equal [ "set", "web", nil, 1 ], [ change.action, change.source, change.client_name, change.rank ]
    assert_not_nil @user.reload.loadout_updated_at
    assert_replays_to_entries @user
  end

  test "tools, models and kinds resolve by name, case-insensitively, and a rank may arrive as text" do
    update(set_pick("2", "claude code", category: "Coding", model: "Claude Opus 5.5"))

    entry = @user.entries.sole
    assert_equal [ 2, tools(:claude_code), ai_models(:opus_5_5) ], [ entry.rank, entry.tool, entry.ai_model ]
  end

  test "editing a slot changes only the fields sent, and null clears one" do
    update(set_pick(1, "cursor", model: "claude-opus-5-5", context: "1m", effort: "high"))

    update({ op: "set_pick", category: "coding", rank: 1, model: "claude-opus-5" })
    entry = @user.entries.sole
    assert_equal [ tools(:cursor), ai_models(:opus_5), "1m", "high" ], [ entry.tool, entry.ai_model, entry.context, entry.effort ]

    update({ op: "set_pick", category: "coding", rank: 1, model: nil, effort: "" })
    entry = @user.entries.sole
    assert_equal [ tools(:cursor), nil, "1m", nil ], [ entry.tool, entry.ai_model, entry.context, entry.effort ]
    assert_replays_to_entries @user
  end

  test "sending what is already saved writes nothing and leaves loadout_updated_at alone" do
    update(set_pick(1, "cursor", context: "1m"))
    @user.update_columns(loadout_updated_at: 1.day.ago)

    assert_no_difference -> { EntryChange.count } do
      result = update(set_pick(1, "cursor", context: "1m"))
      assert_empty result.changes
    end
    assert_in_delta 1.day.ago, @user.reload.loadout_updated_at, 5
  end

  test "context and effort must come from the lists" do
    error = assert_raises(Loadouts::Update::Error) { update(set_pick(1, "cursor", context: "500k")) }
    assert_equal "Context must be one of 200k or 1m.", error.message

    error = assert_raises(Loadouts::Update::Error) { update(set_pick(1, "cursor", effort: "extreme")) }
    assert_equal "Effort must be one of low, medium or high.", error.message

    assert_empty @user.entries
  end

  test "an empty slot needs a tool, and the rank must be 1 to 3" do
    assert_equal "Name a tool.", assert_raises(Loadouts::Update::Error) { update({ op: "set_pick", category: "coding", rank: 1 }) }.message
    assert_equal "Send a rank from 1 to 3.", assert_raises(Loadouts::Update::Error) { update({ op: "set_pick", category: "coding", tool: "cursor" }) }.message
    assert_equal "Send a rank from 1 to 3.", assert_raises(Loadouts::Update::Error) { update(set_pick("first", "cursor")) }.message
    assert_match(/up to 3 picks/, assert_raises(Loadouts::Update::Error) { update(set_pick(4, "cursor")) }.message)
  end

  test "an unknown tool from the web becomes a pending catalog item that shows immediately, with no daily cap" do
    assert_difference -> { Tool.pending.count } => 1 do
      update(set_pick(1, "Hedra", category: "video"))
    end

    tool = Tool.find_by!(name: "Hedra")
    assert_equal [ "pending", @user, "He" ], [ tool.status, tool.created_by, tool.monogram ]
    assert_equal tool, @user.entries.sole.tool

    assert_difference -> { Tool.pending.count } => 6 do
      6.times { |index| update(set_pick(1, "Web tool #{index}")) }
    end
  end

  test "remove_pick and move_pick change the ranks and move loadout_updated_at" do
    update(set_pick(1, "cursor"), set_pick(2, "claude-code"))
    @user.update_columns(loadout_updated_at: 1.day.ago)

    update({ op: "move_pick", category: "coding", rank: 2, direction: "up" })
    assert_equal [ "claude-code", "cursor" ], @user.entries.order(:rank).map { |entry| entry.tool.slug }
    assert_in_delta Time.current, @user.reload.loadout_updated_at, 5

    update({ op: "remove_pick", category: "coding", rank: 1 })
    assert_equal [ [ 1, "cursor" ] ], @user.entries.map { |entry| [ entry.rank, entry.tool.slug ] }
    assert_replays_to_entries @user
  end

  test "several operations in one call replay in order, even inside one instant" do
    freeze_time do
      update(
        set_pick(1, "cursor"), set_pick(2, "claude-code"),
        { op: "remove_pick", category: "coding", rank: 1 },
        set_pick(2, "Zed"), { op: "move_pick", category: "coding", rank: 2, direction: "up" }
      )
    end

    assert_equal [ [ 1, "zed" ], [ 2, "claude-code" ] ], @user.entries.order(:rank).map { |entry| [ entry.rank, entry.tool.slug ] }
    assert_replays_to_entries @user
  end

  test "no agent tool writes picks directly any more" do
    assert_nil ToolRegistry.find("update_loadout")
    assert_not_includes ToolRegistry.manifest[:tools].pluck(:name), "update_loadout"
    assert_not defined?(UpdateLoadoutTool)
  end

  test "a direction must be up or down" do
    update(set_pick(1, "cursor"), set_pick(2, "claude-code"))

    error = assert_raises(Loadouts::Update::Error) { update({ op: "move_pick", category: "coding", rank: 1, direction: "sideways" }) }

    assert_equal "Direction must be up or down.", error.message
  end

  test "the web-only operations raise for every other source before anything is written" do
    Loadouts::Update::WEB_OPERATIONS.each do |op|
      %w[mcp webmcp system].each do |source|
        assert_no_difference [ "Entry.count", "EntryChange.count", "PickSuggestion.count", "Tool.count" ] do
          error = assert_raises(Loadouts::Update::Error, "#{op} from #{source}") do
            update({ op: "suggest", category: "coding", tool: "Some New Tool" }, { op:, category: "coding", rank: 1, tool: "cursor", suggestion_id: 1 }, source:, client_name: "Claude")
          end
          assert_equal "#{op} can only be done by the member on the web.", error.message
        end
      end
    end
  end

  test "agents may only suggest and withdraw" do
    assert_equal %w[suggest withdraw], Loadouts::Update::AGENT_OPERATIONS
    assert_equal %w[set_pick remove_pick move_pick confirm dismiss], Loadouts::Update::WEB_OPERATIONS
  end

  test "errors name what went wrong" do
    error = assert_raises(Loadouts::Update::Error) { update(set_pick(1, "cursor", category: "cooking")) }
    assert_match(/Unknown category "cooking"/, error.message)

    error = assert_raises(Loadouts::Update::Error) { update({ op: "remove_pick", category: "coding", rank: 1 }) }
    assert_match(/Nothing is ranked 1st for coding/, error.message)

    error = assert_raises(Loadouts::Update::Error) { update({ op: "explode", category: "coding" }) }
    assert_match(/Unknown operation "explode"\. Use one of: set_pick, remove_pick, move_pick, confirm, dismiss, suggest, withdraw\./, error.message)

    assert_raises(Loadouts::Update::Error) { Loadouts::Update.call(user: @user, operations: [], source: "web") }
    assert_raises(Loadouts::Update::Error) { update(*Array.new(51) { set_pick(1, "cursor") }) }
    assert_raises(ArgumentError) { update(set_pick(1, "cursor"), source: "carrier pigeon") }
  end

  test "a failing operation rolls back the whole batch" do
    assert_no_difference [ "Entry.count", "EntryChange.count", "Tool.count" ] do
      assert_raises(Loadouts::Update::Error) do
        update(set_pick(1, "cursor"), set_pick(2, "Brand New Tool"), { op: "remove_pick", category: "video", rank: 1 })
      end
    end
  end

  test "a unique-index collision from a racing write comes back as a readable error" do
    racing = Object.new
    def racing.entries = []
    def racing.place(**) = raise(ActiveRecord::RecordNotUnique, "UNIQUE constraint failed: entries.user_id, entries.category_id, entries.rank")

    Loadouts::Slots.define_singleton_method(:new) { |**| racing }
    begin
      error = assert_raises(Loadouts::Update::Error) { update(set_pick(1, "cursor")) }
      assert_equal "That slot changed while you were saving. Reload and try again.", error.message
    ensure
      Loadouts::Slots.singleton_class.remove_method(:new)
    end
  end

  test "a new agent-created tool or model counts toward five a day, and naming one again costs nothing" do
    suggest = ->(name) { update({ op: "suggest", category: "coding", tool: name }, source: "mcp", client_name: "Claude", oauth_client_id: 7) }

    assert_difference -> { Tool.pending.count } => 1 do
      2.times { suggest.("Agent Tool 0") }
    end
    4.times { |index| suggest.("Agent Tool #{index + 1}") }

    assert_no_difference -> { Tool.count } do
      error = assert_raises(Loadouts::Update::Error) { suggest.("Agent Tool 5") }
      assert_match(/5 new tools or models a day/, error.message)
      suggest.("Agent Tool 0")
    end

    travel 25.hours do
      assert_difference -> { Tool.pending.count } => 1 do
        suggest.("Agent Tool 5")
      end
    end
  end

  test "agent-named unknown models count toward the same daily five" do
    2.times { |index| update({ op: "suggest", category: "coding", tool: "Agent Tool #{index}", model: "Agent Model #{index}" }, source: "webmcp") }
    update({ op: "suggest", category: "coding", tool: "Agent Tool 2" }, source: "webmcp")

    assert_equal [ "pending", @user ], AiModel.find_by!(name: "Agent Model 1").then { |model| [ model.status, model.created_by ] }
    assert_no_difference -> { AiModel.count } do
      error = assert_raises(Loadouts::Update::Error) do
        update({ op: "suggest", category: "coding", tool: "cursor", model: "Agent Model 2" }, source: "webmcp")
      end
      assert_match(/5 new tools or models a day/, error.message)
    end
  end
end
