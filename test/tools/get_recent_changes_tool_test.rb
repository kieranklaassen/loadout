# frozen_string_literal: true

require "test_helper"

class GetRecentChangesToolTest < ActiveSupport::TestCase
  def changes(user, arguments = { limit: 20 })
    result = ToolRegistry.call("get_recent_changes", arguments:, user:, source: "webmcp")
    assert_equal false, result[:isError], result[:content].first[:text]
    JSON.parse(result[:content].first[:text])["changes"]
  end

  test "tells the member's whole story newest first: suggested, confirmed and dismissed included" do
    user = users(:every_cy)
    suggest = ->(tool) { Toolbox::Update.call(user:, operations: [ { op: "suggest", category: "video", tool: } ], source: "mcp", client_name: "Claude Code", oauth_client_id: 9).suggestions.sole }
    confirmed = suggest.("runway")
    travel 1.minute
    Toolbox::Update.call(user:, operations: [ { op: "confirm", suggestion_id: confirmed.id } ], source: "web")
    travel 1.minute
    dismissed = suggest.("Hedra")
    Toolbox::Update.call(user:, operations: [ { op: "dismiss", suggestion_id: dismissed.id } ], source: "web")

    story = changes(user).first(4).map { |change| change.values_at("sentence", "action", "source", "client_name") }

    assert_equal [
      [ "Dismissed the suggestion of Hedra for video", "dismissed", "web", nil ],
      [ "Claude Code suggested Hedra for video", "suggested", "mcp", "Claude Code" ],
      [ "Confirmed Runway as first pick for video", "confirmed", "web", nil ],
      [ "Claude Code suggested Runway for video", "suggested", "mcp", "Claude Code" ]
    ], story
  end

  test "baseline rows carried over by the migration are not events" do
    user = users(:every_cy)
    EntryChange.create!(user:, category: categories(:coding), tool: tools(:cursor), action: "baseline", source: "system", rank: 1)

    assert_not_includes changes(user).pluck("action"), "baseline"
  end

  test "an agent's name is data: trimmed and stripped of control and format characters" do
    user = users(:every_cy)
    EntryChange.create!(user:, category: categories(:video), tool: tools(:runway), action: "suggested", source: "mcp", rank: 1, client_name: "Evil‮​\n#{"x" * 200}")

    change = changes(user).first
    assert_operator change["client_name"].length, :<=, 80
    assert_no_match(/[[:cntrl:]]|\p{Cf}/, change["client_name"] + change["sentence"])
  end

  test "only reads the signed-in member's changes" do
    assert_empty changes(users(:one))
  end

  test "rejects a limit outside 1..50" do
    assert ToolRegistry.call("get_recent_changes", arguments: { limit: 500 }, user: users(:every_cy), source: "webmcp")[:isError]
  end
end
