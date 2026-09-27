require "test_helper"

class MapStatsTest < ActiveSupport::TestCase
  setup do
    @coding = categories(:coding)
  end

  test "AE4: five Every members use Cursor, two are public, so two are named and three are others" do
    add_member("dee@every.to", handle: "dee", public: true)
    add_member("eli@every.to", handle: "eli", public: false)
    add_member("fay@every.to", handle: nil, public: true)

    cursor = rank(MapStats.new.category(@coding)[:tools], "cursor")

    assert_equal 5, cursor[:count]
    assert_equal %w[ana dee], cursor[:people].pluck(:handle)
    assert_equal 3, cursor[:others_count]
    assert_equal 1.0, cursor[:share]
  end

  test "private profiles are never named" do
    panel = MapStats.new.category(@coding)
    names = (panel[:tools] + panel[:models]).flat_map { |row| row[:people] }.pluck(:handle)

    assert_includes names, "ana"
    assert_not_includes names, "cy"
    assert_equal 1, rank(panel[:models], "claude-opus-5")[:others_count]
    assert_not_includes MapStats.new.people(@coding).pluck(:handle), "cy"
  end

  test "people outside Every are left out of every count" do
    update(users(:one), tool: "cursor", model: "claude-opus-5-5")
    update(users(:two), tool: "claude-code")

    stats = MapStats.new
    panel = stats.category(@coding)

    assert_equal 2, panel[:people_count]
    assert_equal 2, rank(panel[:tools], "cursor")[:count]
    assert_nil rank(panel[:tools], "claude-code")
    assert_equal 2, stats.summary[:members]
  end

  test "tools rank by distinct people and carry the model most people pair them with" do
    add_member("dee@every.to", handle: "dee", public: true, tool: "claude-code", model: "claude-opus-5-5")

    tools = MapStats.new.category(@coding)[:tools]

    assert_equal %w[cursor claude-code], tools.map { |row| row[:item][:slug] }
    assert_equal 0.3333, tools.second[:share]
    assert_equal "claude-opus-5", tools.first[:usual_model][:slug]
  end

  test "discovery lists the categories the viewer has not filled in, with what colleagues use there" do
    add_member("dee@every.to", handle: "dee", public: true, category: "video", tool: "runway")

    empty = MapStats.new(viewer: users(:every_cy)).discovery[:empty_categories]

    assert_equal %w[knowledge-work video], empty.map { |row| row[:category][:slug] }
    video = empty.find { |row| row[:category][:slug] == "video" }
    assert_equal "runway", video[:tools].first[:item][:slug]
    assert_equal 1, video[:tools].first[:count]
  end

  test "discovery points out colleagues who moved to a newer model in the same family" do
    add_member("dee@every.to", handle: "dee", public: false, model: "claude-opus-5-5")

    upgrades = MapStats.new(viewer: users(:every_cy)).discovery[:upgrades]

    assert_equal 1, upgrades.size
    assert_equal "claude-opus-5", upgrades.first[:from_model][:slug]
    assert_equal "claude-opus-5-5", upgrades.first[:to_model][:slug]
    assert_equal "cursor", upgrades.first[:tool][:slug]
    assert_equal 2, upgrades.first[:colleagues_count]
  end

  test "no upgrade hint when the viewer already uses the newest model" do
    assert_empty MapStats.new(viewer: users(:every_ana)).discovery[:upgrades]
  end

  test "the viewer's own picks are marked as in their loadout" do
    tools = MapStats.new(viewer: users(:every_ana)).category(@coding)[:tools]

    assert rank(tools, "cursor")[:in_loadout]
  end

  private

  def rank(rows, slug)
    rows.find { |row| row[:item][:slug] == slug }
  end

  def add_member(email, handle:, public:, category: "coding", tool: "cursor", model: nil)
    user = User.create!(email_address: email, handle:, public:, name: email.split("@").first.capitalize)
    update(user, category:, tool:, model:)
  end

  def update(user, category: "coding", tool: "cursor", model: nil)
    Loadouts::Update.call(user:, operations: [ { op: "add", category:, tool:, model: } ], source: "web")
    user
  end
end
