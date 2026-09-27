# frozen_string_literal: true

require "test_helper"

class GetMyLoadoutToolTest < ActiveSupport::TestCase
  def loadout(user)
    result = ToolRegistry.call("get_my_loadout", arguments: {}, user:, source: "webmcp")
    assert_equal false, result[:isError], result[:content].first[:text]
    JSON.parse(result[:content].first[:text])
  end

  test "returns every kind with the member's ranked picks and open suggestions" do
    body = loadout(users(:every_ana))

    assert_equal [ "ana", "link", "/ana", "/loadout/edit", 1 ], body.values_at("handle", "visibility", "url", "confirm_at", "to_confirm")
    assert_equal %w[coding knowledge-work video], body["kinds"].map { |kind| kind["slug"] }

    coding = body["kinds"].first
    assert_equal [ [ 1, "cursor", "claude-opus-5-5", "1m", "high" ], [ 2, "claude-code", nil, nil, nil ] ],
      coding["picks"].map { |pick| [ pick["rank"], pick.dig("tool", "slug"), pick.dig("model", "slug"), pick["context"], pick["effort"] ] }
    assert_equal 0, coding["to_confirm"]

    video = body["kinds"].last
    assert_empty video["picks"]
    assert_equal 1, video["to_confirm"]
    waiting = video["suggestions"].sole
    assert_equal [ "runway", 1, "WebMCP" ], [ waiting.dig("tool", "slug"), waiting["rank_hint"], waiting["suggested_by"] ]
  end

  test "shows the suggestions an agent just made and how many wait" do
    user = users(:every_dee)
    ToolRegistry.call(
      "suggest_picks", arguments: { operations: [ { op: "suggest", category: "coding", tool: "cursor", model: "claude-opus-5-5", context: "1m" } ] },
      user:, source: "mcp", client_name: "Claude Code", oauth_client_id: 5
    )

    body = loadout(user)
    coding = body["kinds"].first
    suggestion = coding["suggestions"].sole
    assert_equal 1, body["to_confirm"]
    assert_equal [ "cursor", "claude-opus-5-5", "1m", "Claude Code" ], [ suggestion.dig("tool", "slug"), suggestion.dig("model", "slug"), suggestion["context"], suggestion["suggested_by"] ]
    replaces = suggestion["replaces"]
    assert_equal [ 2, "cursor", "gpt-6-astra" ], [ replaces["rank"], replaces.dig("tool", "slug"), replaces.dig("model", "slug") ]
  end

  test "only ever reads the signed-in member, with no page of their own yet" do
    body = loadout(users(:one))

    assert_equal [ nil, "only_me", 0 ], body.values_at("url", "visibility", "to_confirm")
    assert(body["kinds"].all? { |kind| kind["picks"].empty? && kind["suggestions"].empty? })
  end

  test "carries slugs and names only, and an agent's name as trimmed data" do
    user = users(:every_dee)
    ToolRegistry.call(
      "suggest_picks", arguments: { operations: [ { op: "suggest", category: "video", tool: "runway" } ] },
      user:, source: "mcp", client_name: "Agent‮​\n#{"x" * 200}", oauth_client_id: 5
    )

    body = loadout(user)
    name = body["kinds"].last["suggestions"].sole["suggested_by"]
    assert_operator name.length, :<=, 80
    assert_no_match(/[[:cntrl:]]|\p{Cf}/, name)
    assert_no_match(/hue|monogram|mark/, body.to_json)
  end
end
