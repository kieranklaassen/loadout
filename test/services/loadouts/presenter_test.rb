require "test_helper"

class Loadouts::PresenterTest < ActiveSupport::TestCase
  def update(user, *operations, source: "web", **context)
    Loadouts::Update.call(user:, operations:, source:, **context)
  end

  def suggest(user, tool, category: "coding", **fields)
    update(user, { op: "suggest", category:, tool:, **fields }, source: "mcp", client_name: "Claude", oauth_client_id: 5).suggestions.sole
  end

  def kind(user, slug)
    Loadouts::Presenter.new(user).kinds.find { |kind| kind[:category][:slug] == slug }
  end

  test "kinds lists every kind in catalog order with the confirmed picks by rank" do
    kinds = Loadouts::Presenter.new(users(:every_ana)).kinds

    assert_equal %w[coding knowledge-work video], kinds.map { |kind| kind[:category][:slug] }
    assert_equal({ slug: "coding", name: "Coding", blurb: "Writing, reviewing, and shipping code." }, kinds.first[:category])
    picks = kinds.first[:picks]
    assert_equal [ [ 1, "cursor", "claude-opus-5-5", "1m", "high" ], [ 2, "claude-code", nil, nil, nil ] ],
      picks.map { |pick| [ pick[:rank], pick[:tool][:slug], pick[:model]&.dig(:slug), pick[:context], pick[:effort] ] }
    assert_equal %i[rank tool model context effort], picks.first.keys
    assert_equal({ slug: "cursor", name: "Cursor", kind: "tool" }, picks.first[:tool].slice(:slug, :name, :kind))
    assert_empty kinds.second[:suggestions]
  end

  test "the owner's picks are the ones their profile shows, with a pending tool or model marked" do
    user = users(:one)
    update(user, { op: "set_pick", category: "coding", rank: 1, tool: "Zed", model: "Beta Model" }, { op: "set_pick", category: "coding", rank: 2, tool: "cursor" })

    picks = kind(user, "coding")[:picks]
    assert_equal [ [ 1, "zed", true, "beta-model", true ], [ 2, "cursor", false, nil, nil ] ],
      picks.map { |pick| [ pick[:rank], pick[:tool][:slug], pick[:tool][:pending], pick[:model]&.dig(:slug), pick[:model]&.dig(:pending) ] }

    profile = PersonPicks.new(viewer: user).for(user)[:kinds].find { |profile_kind| profile_kind[:category][:slug] == "coding" }
    assert_equal profile[:picks], picks
  end

  test "team_top is what the member's own audience uses, keyed by kind" do
    top = Loadouts::Presenter.new(users(:every_ana)).team_top

    assert_equal %w[coding knowledge-work video], top.keys
    assert_equal [ [ "claude-code", 2 ], [ "cursor", 1 ] ], top["coding"][:tools].map { |tool| [ tool[:item][:slug], tool[:yours_rank] ] }
    assert_equal({ tools: [], models: [] }, top["video"])
  end

  test "an open suggestion shows where it would land, who suggested it and how many wait" do
    video = kind(users(:every_ana), "video")

    assert_empty video[:picks]
    assert_equal 1, video[:to_confirm]
    suggestion = video[:suggestions].sole
    assert_equal %i[category context effort id model replaces slot_hint suggested_at suggested_by target_rank tool], suggestion.keys.sort
    assert_equal [ pick_suggestions(:ana_runway).id, "video", "runway", nil, 1, 1, "WebMCP" ],
      [ suggestion[:id], suggestion[:category], suggestion[:tool][:slug], suggestion[:replaces], suggestion[:slot_hint], suggestion[:target_rank], suggestion[:suggested_by] ]
    assert_equal pick_suggestions(:ana_runway).created_at.iso8601, suggestion[:suggested_at]
  end

  test "the target is the hint when empty, else the first empty slot, else none" do
    user = users(:one)
    update(user, { op: "set_pick", category: "coding", rank: 1, tool: "cursor" })
    hinted = suggest(user, "claude-code", rank: 3)
    occupied_hint = suggest(user, "Windsurf", rank: 1)

    targets = kind(user, "coding")[:suggestions].to_h { |suggestion| [ suggestion[:id], suggestion[:target_rank] ] }
    assert_equal({ hinted.id => 3, occupied_hint.id => 2 }, targets)

    update(user, { op: "set_pick", category: "coding", rank: 2, tool: "Zed" }, { op: "set_pick", category: "coding", rank: 3, tool: "runway" })
    assert_equal [ nil, nil ], kind(user, "coding")[:suggestions].map { |suggestion| suggestion[:target_rank] }
  end

  test "a change to a confirmed pick targets that slot and shows what it replaces" do
    user = users(:one)
    update(user, { op: "set_pick", category: "coding", rank: 2, tool: "cursor", model: "claude-opus-5-5" })
    suggest(user, "cursor", model: "claude-opus-5", rank: 1)

    suggestion = kind(user, "coding")[:suggestions].sole
    assert_equal 2, suggestion[:target_rank]
    assert_equal [ 2, "cursor", "claude-opus-5-5" ], suggestion[:replaces].then { |replaces| [ replaces[:rank], replaces[:tool][:slug], replaces[:model][:slug] ] }
  end

  test "only the owner's open suggestions are listed" do
    user = users(:one)
    open = suggest(user, "cursor")
    dismissed = suggest(user, "claude-code")
    update(user, { op: "dismiss", suggestion_id: dismissed.id })
    old = suggest(user, "Windsurf")
    old.update_columns(created_at: 31.days.ago)

    listed = kind(user, "coding")
    assert_equal [ open.id ], listed[:suggestions].map { |suggestion| suggestion[:id] }
    assert_equal 1, listed[:to_confirm]
    assert_empty kind(users(:every_dee), "video")[:suggestions]
  end
end
