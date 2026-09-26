# frozen_string_literal: true

require "test_helper"

class GetRecentChangesToolTest < ActiveSupport::TestCase
  test "returns the member's changes as sentences, newest first" do
    user = users(:every_cy)
    Loadouts::Update.call(user:, operations: [ { op: "add", category: "video", tool: "runway" } ], source: "mcp", client_name: "Claude Code")

    result = ToolRegistry.call("get_recent_changes", arguments: { limit: 5 }, user:, source: "webmcp")

    assert_equal false, result[:isError]
    change = JSON.parse(result[:content].first[:text])["changes"].first
    assert_equal [ "Added Runway for video", "mcp", "Claude Code" ], change.values_at("sentence", "source", "client_name")
  end

  test "rejects a limit outside 1..50" do
    assert ToolRegistry.call("get_recent_changes", arguments: { limit: 500 }, user: users(:every_cy), source: "webmcp")[:isError]
  end
end
