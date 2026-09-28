require "test_helper"

class Settings::HistoriesControllerTest < ActionDispatch::IntegrationTest
  test "signed out, the download asks for sign-in" do
    get settings_history_path

    assert_redirected_to new_session_path
  end

  test "a member who has not finished onboarding is sent to the claim page" do
    sign_in_as users(:one)

    get settings_history_path

    assert_redirected_to welcome_path
  end

  test "the download is a JSON attachment that browsers may not sniff or store" do
    sign_in_as users(:every_ana)

    get settings_history_path

    assert_response :success
    assert_equal "application/json", response.media_type
    assert_match(/\Aattachment;/, response.headers["Content-Disposition"])
    assert_match(/toolbox-history\.json/, response.headers["Content-Disposition"])
    assert_equal "nosniff", response.headers["X-Content-Type-Options"]
    assert_includes response.headers["Cache-Control"], "no-store"
  end

  test "it holds every one of the member's own rows, oldest first, private-era ones and suggestions included" do
    sign_in_as users(:every_ana)

    get settings_history_path

    changes = JSON.parse(response.body).fetch("changes")
    assert_equal 7, changes.size
    assert_equal changes.map { |change| change["at"] }, changes.map { |change| change["at"] }.sort
    assert_includes changes.map { |change| change["action"] }, "suggested"
    assert_equal(
      { "kind" => "coding", "tool" => "claude-code", "model" => nil, "action" => "set", "rank" => 1, "from_rank" => nil,
        "context" => nil, "effort" => nil, "source" => "web", "client_name" => nil },
      changes.first.slice("kind", "tool", "model", "action", "rank", "from_rank", "context", "effort", "source", "client_name")
    )
    moved = changes.find { |change| change["action"] == "moved" && change["tool"] == "cursor" }
    assert_equal({ "rank" => 1, "from_rank" => 2, "model" => "claude-opus-5-5" }, moved.slice("rank", "from_rank", "model"))
  end

  test "baseline rows are part of the download" do
    ana = users(:every_ana)
    ana.entry_changes.create!(category: categories(:knowledge_work), tool: tools(:claude), action: "baseline", source: "system", rank: 3)
    sign_in_as ana

    get settings_history_path

    changes = JSON.parse(response.body).fetch("changes")
    assert_equal 8, changes.size
    assert_equal [ "system" ], changes.select { |change| change["action"] == "baseline" }.map { |change| change["source"] }
  end

  test "a hidden member downloads their own private-era history and nobody else's" do
    sign_in_as users(:every_cy)

    get settings_history_path, params: { user_id: users(:every_ana).id, handle: "ana" }

    changes = JSON.parse(response.body).fetch("changes")
    assert_equal 1, changes.size
    assert_equal [ "cursor" ], changes.map { |change| change["tool"] }
  end

  test "an agent's display name is data: quotes, angle brackets and control characters survive the round trip" do
    name = %(Evil "Agent" </script><img src=x onerror=alert(1)>\u0007)
    ana = users(:every_ana)
    ana.entry_changes.create!(category: categories(:video), tool: tools(:runway), action: "suggested", source: "mcp", client_name: name, rank: 1)
    sign_in_as ana

    get settings_history_path

    assert_equal "application/json", response.media_type
    assert_equal name, JSON.parse(response.body).fetch("changes").find { |change| change["source"] == "mcp" }["client_name"]
  end
end
