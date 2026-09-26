# frozen_string_literal: true

require "test_helper"

class UpdateLoadoutToolTest < ActiveSupport::TestCase
  setup { @user = users(:every_cy) }

  def update(operations, source: "mcp", client_name: "Claude Code")
    ToolRegistry.call("update_loadout", arguments: { operations: }, user: @user, source:, client_name:)
  end

  def payload(result)
    assert_equal false, result[:isError], result[:content].first[:text]
    JSON.parse(result[:content].first[:text])
  end

  test "switching a model returns the story sentence and the new loadout, recording source and client" do
    body = payload(update([
      { op: "remove", category: "coding", tool: "cursor", model: "claude-opus-5" },
      { op: "add", category: "coding", tool: "cursor", model: "claude-opus-5-5", primary: true }
    ]))

    assert_equal [ "Switched coding model from Claude Opus 5 to Claude Opus 5.5 in Cursor" ], body["changes"]
    assert_equal "claude-opus-5-5", body.dig("categories", 0, "entries", 0, "model", "slug")
    assert_equal [ [ "mcp", "Claude Code" ] ], @user.entry_changes.distinct.pluck(:source, :client_name)
  end

  test "an unknown tool becomes a pending catalog item on the member's loadout (AE5)" do
    body = nil
    assert_difference -> { Tool.pending.count } => 1 do
      body = payload(update([ { op: "add", category: "video", tool: "Hedra" } ]))
    end

    hedra = Tool.find_by!(name: "Hedra")
    assert_equal [ "pending", @user ], [ hedra.status, hedra.created_by ]
    video = body["categories"].find { |category| category["slug"] == "video" }
    assert_equal [ "Hedra", true ], [ video.dig("entries", 0, "tool", "name"), video.dig("entries", 0, "tool", "pending") ]
  end

  test "replace_category takes the complete list of picks" do
    body = payload(update([ { op: "replace_category", category: "coding", picks: [ { tool: "claude-code", model: nil, primary: true } ] } ]))

    assert_equal [ "Switched coding from Cursor with Claude Opus 5 to Claude Code" ], body["changes"]
    assert_equal [ "claude-code" ], @user.entries.map { |entry| entry.tool.slug }
  end

  test "a write-path error is an isError result the agent can read" do
    result = update([ { op: "remove", category: "video", tool: "runway" } ])

    assert result[:isError]
    assert_match(/not in your video loadout/, result[:content].first[:text])
  end

  test "the input schema rejects unknown operations and fields before writing" do
    assert_no_difference -> { EntryChange.count } do
      assert update([ { op: "delete_account", category: "coding" } ])[:isError]
      assert update([ { op: "add", category: "coding", tool: "cursor", visibility: "public" } ])[:isError]
      assert update([])[:isError]
    end
  end
end
