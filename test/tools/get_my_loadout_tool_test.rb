# frozen_string_literal: true

require "test_helper"

class GetMyLoadoutToolTest < ActiveSupport::TestCase
  test "returns the member's loadout grouped by category" do
    result = ToolRegistry.call("get_my_loadout", arguments: {}, user: users(:every_ana), source: "webmcp")

    assert_equal false, result[:isError]
    loadout = JSON.parse(result[:content].first[:text])
    assert_equal "ana", loadout["handle"]
    assert_equal %w[coding knowledge-work], loadout["categories"].map { |category| category["slug"] }
    coding = loadout["categories"].first["entries"].first
    assert_equal [ "cursor", "claude-opus-5-5", true ], [ coding.dig("tool", "slug"), coding.dig("model", "slug"), coding["primary"] ]
  end

  test "only ever reads the signed-in member" do
    result = ToolRegistry.call("get_my_loadout", arguments: {}, user: users(:one), source: "webmcp")

    assert_equal [], JSON.parse(result[:content].first[:text])["categories"]
  end
end
