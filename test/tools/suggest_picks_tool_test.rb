# frozen_string_literal: true

require "test_helper"

class SuggestPicksToolTest < ActiveSupport::TestCase
  setup { @user = users(:every_dee) }

  def suggest(operations, source: "mcp", client_name: "Claude Code", oauth_client_id: 42, user: @user)
    ToolRegistry.call("suggest_picks", arguments: { operations: }, user:, source:, client_name:, oauth_client_id:)
  end

  def payload(result)
    assert_equal false, result[:isError], result[:content].first[:text]
    JSON.parse(result[:content].first[:text])
  end

  def error_text(result)
    assert result[:isError], "expected an error, got #{result[:content].first[:text]}"
    result[:content].first[:text]
  end

  test "over MCP it stores a suggestion that carries the OAuth client id and leaves the loadout alone (AE3)" do
    body = nil
    assert_no_difference -> { Entry.count } do
      assert_difference -> { @user.pick_suggestions.open.count } => 1 do
        body = payload(suggest([ { op: "suggest", category: "video", tool: "runway", context: "1m", effort: "high", rank: 2 } ]))
      end
    end

    suggestion = @user.pick_suggestions.open.sole
    assert_equal [ "video", "runway", 42, "Claude Code", "1m", "high", 2 ],
      [ suggestion.category.slug, suggestion.tool.slug, suggestion.oauth_client_id, suggestion.client_name, suggestion.context, suggestion.effort, suggestion.slot_hint ]
    assert_equal [ suggestion.id, "video", "runway", nil, "1m", "high", 2 ],
      body["suggestions"].sole.values_at("id", "category", "tool", "model", "context", "effort", "rank_hint")
    assert_equal [ [ "suggested", "mcp", "Claude Code" ] ], @user.entry_changes.where(action: "suggested").pluck(:action, :source, :client_name)
  end

  test "over WebMCP it stores a suggestion with no client id" do
    payload(suggest([ { op: "suggest", category: "video", tool: "runway" } ], source: "webmcp", client_name: nil, oauth_client_id: nil))

    suggestion = @user.pick_suggestions.open.sole
    assert_equal [ nil, "WebMCP" ], [ suggestion.oauth_client_id, suggestion.client_name ]
    assert_equal [ [ "suggested", "webmcp" ] ], @user.entry_changes.where(action: "suggested").pluck(:action, :source)
  end

  test "the result says nothing is on the page until the member confirms, and links to the editor" do
    text = payload(suggest([ { op: "suggest", category: "video", tool: "runway" }, { op: "suggest", category: "coding", tool: "windsurf" } ]))["message"]

    assert_match(/nothing is on the member's page yet/i, text)
    assert_match(/until the member confirms it on the site/, text)
    assert_includes text, "/loadout/edit?kind=video"
    assert_includes text, "/loadout/edit?kind=coding"
  end

  test "colleagues see nothing of a suggestion" do
    colleague = users(:every_ana)
    before = TeamRankings.new(viewer: colleague).overall
    video_before = TeamRankings.new(viewer: colleague).kind(categories(:video))

    payload(suggest([ { op: "suggest", category: "video", tool: "runway", rank: 1 } ]))

    assert_equal before, TeamRankings.new(viewer: colleague).overall
    assert_equal video_before, TeamRankings.new(viewer: colleague).kind(categories(:video))
    assert_equal 0, @user.entries.where(category: categories(:video)).count
  end

  test "withdraw closes the client's own suggestion and no other client's" do
    suggested = payload(suggest([ { op: "suggest", category: "video", tool: "runway" } ]))["suggestions"].sole["id"]

    assert_match(/no longer open/, error_text(suggest([ { op: "withdraw", suggestion_id: suggested } ], oauth_client_id: 43)))
    assert_equal "open", PickSuggestion.find(suggested).status

    body = payload(suggest([ { op: "withdraw", suggestion_id: suggested } ]))
    assert_equal [ suggested ], body["withdrawn"]
    assert_match(/Withdrew 1 suggestion/, body["message"])
    assert_equal "withdrawn", PickSuggestion.find(suggested).status
  end

  test "a suggestion a later operation of the same call supersedes is not reported as proposed" do
    body = payload(suggest([
      { op: "suggest", category: "coding", tool: "cursor", effort: "high" },
      { op: "suggest", category: "coding", tool: "cursor", model: "claude-opus-5-5" }
    ]))

    open = @user.pick_suggestions.open.sole
    assert_equal [ [ open.id, "claude-opus-5-5" ] ], body["suggestions"].map { |entry| entry.values_at("id", "model") }
    assert_equal [], body["withdrawn"]
    assert_match(/Suggested 1 pick\./, body["message"])
    assert_equal [ "superseded", "open" ], @user.pick_suggestions.order(:id).pluck(:status)
  end

  test "four suggestions for one kind in one call report the three that stay open" do
    body = payload(suggest(%w[cursor claude-code Windsurf Zed].map { |tool| { op: "suggest", category: "coding", tool:, effort: "low" } }))

    assert_equal @user.pick_suggestions.open.order(:id).pluck(:id), body["suggestions"].map { |entry| entry["id"] }
    assert_equal [ "Claude Code", "Windsurf", "Zed" ], body["suggestions"].map { |entry| Tool.find_by!(slug: entry["tool"]).name }
    assert_equal [], body["withdrawn"]
    assert_match(/Suggested 3 picks\./, body["message"])
  end

  test "a call that withdraws one suggestion and makes another reports each under its own heading" do
    old = payload(suggest([ { op: "suggest", category: "video", tool: "runway" } ]))["suggestions"].sole["id"]

    body = payload(suggest([ { op: "withdraw", suggestion_id: old }, { op: "suggest", category: "coding", tool: "cursor", effort: "high" } ]))

    assert_equal [ old ], body["withdrawn"]
    assert_equal [ @user.pick_suggestions.open.sole.id ], body["suggestions"].map { |entry| entry["id"] }
    assert_match(/Suggested 1 pick\..*Withdrew 1 suggestion\./, body["message"])
  end

  test "a change to a pick reports only the fields the agent named; the description says the rest keep the member's values" do
    assert_match(/a field you leave out keeps the member's current value/, SuggestPicksTool.description)

    body = payload(suggest([ { op: "suggest", category: "coding", tool: "claude-code", context: "1m" } ]))

    assert_equal [ "claude-code", nil, "1m", nil ], body["suggestions"].sole.values_at("tool", "model", "context", "effort")
    mine = JSON.parse(ToolRegistry.call("get_my_loadout", arguments: {}, user: @user, source: "mcp")[:content].first[:text])
    assert_equal [ nil, "1m", nil ], mine["kinds"].find { |kind| kind["slug"] == "coding" }["suggestions"].sole.values_at("model", "context", "effort")
  end

  test "an exact suggestion the member dismissed is refused with a readable reason" do
    id = payload(suggest([ { op: "suggest", category: "video", tool: "runway" } ]))["suggestions"].sole["id"]
    Loadouts::Update.call(user: @user, operations: [ { op: "dismiss", suggestion_id: id } ], source: "web")

    assert_match(/dismissed on .* do not suggest it again/i, error_text(suggest([ { op: "suggest", category: "video", tool: "runway" } ])))
  end

  test "a rank hint above three, a bad context or effort, and an unknown kind are readable errors" do
    assert_no_difference -> { PickSuggestion.count } do
      assert_match(/rank/, error_text(suggest([ { op: "suggest", category: "video", tool: "runway", rank: 4 } ])))
      assert_match(/context/, error_text(suggest([ { op: "suggest", category: "video", tool: "runway", context: "2m" } ])))
      assert_match(/effort/, error_text(suggest([ { op: "suggest", category: "video", tool: "runway", effort: "extreme" } ])))
      assert_match(/Unknown category "cooking". Use one of: coding, knowledge-work, video/, error_text(suggest([ { op: "suggest", category: "cooking", tool: "runway" } ])))
      assert_match(/Name a tool/, error_text(suggest([ { op: "suggest", category: "video" } ])))
    end
  end

  test "the schema accepts only the two agent operations and the shared enums" do
    item = SuggestPicksTool.input_schema.to_h.dig(:properties, :operations, :items, :properties)

    assert_equal %w[suggest withdraw], item.dig(:op, :enum)
    assert_equal [ *Entry::CONTEXTS, nil ], item.dig(:context, :enum)
    assert_equal [ *Entry::EFFORTS, nil ], item.dig(:effort, :enum)
    assert_equal Entry::MAX_RANK, item.dig(:rank, :maximum)
  end

  test "anything that is the member's decision fails the schema and changes nothing (AE7)" do
    attempts = [
      [ { op: "confirm", suggestion_id: 1 } ],
      [ { op: "dismiss", suggestion_id: 1 } ],
      [ { op: "set_pick", category: "video", rank: 1, tool: "runway" } ],
      [ { op: "remove_pick", category: "coding", rank: 1 } ],
      [ { op: "move_pick", category: "coding", rank: 2, direction: "up" } ],
      [ { op: "suggest", category: "video", tool: "runway", confirmed: true } ],
      [ { op: "suggest", category: "video", tool: "runway", visibility: "link" } ]
    ]

    assert_no_difference [ -> { Entry.count }, -> { PickSuggestion.count }, -> { EntryChange.count } ] do
      attempts.each { |operations| assert error_text(suggest(operations)).present?, operations.inspect }
      assert error_text(ToolRegistry.call("suggest_picks", arguments: { operations: [ { op: "suggest", category: "video", tool: "runway" } ], confirmed: true }, user: @user, source: "mcp"))
      assert error_text(ToolRegistry.call("suggest_picks", arguments: { operations: [] }, user: @user, source: "mcp"))
    end
    assert_equal "team", @user.reload.visibility
  end
end
