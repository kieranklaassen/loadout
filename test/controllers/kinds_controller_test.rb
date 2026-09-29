require "test_helper"

# The Kind page is the same read layer as Home, one kind deep. Expectations come from the
# fixture facts in test/fixtures (users.yml, entries.yml): a team viewer reads the Every team
# class, which holds ana and dee (M = 2); a visitor reads ana alone (M = 1); the "others"
# class holds eli and fay; cy is only me and must never be named to a colleague.
class KindsControllerTest < ActionDispatch::IntegrationTest
  include SurfaceHelper

  def kind_props = page_props.slice(:filters, :notice, :category, :ranked, :tools, :models, :setups, :takes, :last_update_at, :eras, :cta)
  def listing(list, slug) = list.find { |entry| entry[:item][:slug] == slug }
  def slugs(list) = list.map { |entry| entry[:item][:slug] }

  # { 1 => ["Ana Every"], 2 => [...], 3 => [...] }, whatever the keys serialise as.
  def names_by_rank(entry) = entry[:by_rank].to_h { |rank, people| [ rank.to_s.to_i, people.map { |person| person[:name] } ] }

  # The signed-in member who has finished onboarding but ranked nothing.
  def newcomer
    users(:one).tap { |user| user.update!(handle: "newcomer", name: "New Comer", onboarded_at: Time.current) }
  end

  # A verified @every.to member who shares with the team.
  def teammate(handle) = add_person(handle, visibility: "team", team: true)

  def rank(user, position, tool, model: nil, category: "coding", **choices)
    Toolbox::Update.call(
      user:, source: "web",
      operations: [ { op: "set_pick", category:, rank: position, tool: tool.slug, model: model&.slug, **choices } ]
    )
  end

  # Cursor leads on people alone: two of them rank it, and every other tool has one. Fixture
  # people go first so the room is exactly the one built here.
  def three_teammates
    User.delete_all
    travel_to Time.utc(2026, 1, 5, 10)
    zed, windsurf = add_tool("Zed"), add_tool("Windsurf")
    ana, bob, cyd = %w[ana bob cyd].map { |handle| teammate(handle) }
    rank ana, 1, zed
    rank ana, 2, tools(:cursor)
    rank bob, 1, windsurf
    rank bob, 2, tools(:cursor)
    rank cyd, 1, tools(:claude_code)
  end

  # AE1: Home and the Kind page count the same people

  test "AE1: the per-rank names add up to the tool's N, K counts people with a Coding pick, and Home agrees" do
    bob, cyd, eve, fred = %w[bob cyd eve fred].map { |handle| teammate(handle) }
    zed, windsurf = add_tool("Zed"), add_tool("Windsurf")
    add_pick bob, :coding, 1, :cursor
    add_pick cyd, :coding, 1, zed
    add_pick cyd, :coding, 2, windsurf
    add_pick cyd, :coding, 3, :cursor
    add_pick eve, :coding, 1, :claude_code
    add_pick fred, :knowledge_work, 1, :claude
    sign_in_as users(:every_dee)

    get kind_path("coding")

    assert_response :success
    assert_inertia_component "kinds/show"
    assert_equal({ n: 5, of: 6 }, page_props[:ranked], "ana, dee, bob, cyd and eve have a Coding pick; fred does not")
    cursor = listing(page_props[:tools], "cursor")
    assert_equal({ n: 4, of: 6 }, cursor[:count])
    assert_equal({ 1 => [ "Ana Every", "Bob" ], 2 => [ "Dee Every" ], 3 => [ "Cyd" ] }, names_by_rank(cursor))
    assert_equal cursor[:count][:n], names_by_rank(cursor).values.sum(&:size)
    page_props[:tools].each { |tool| assert_equal tool[:count][:n], names_by_rank(tool).values.sum(&:size), "#{tool[:item][:name]} names add up" }

    get root_path
    home = page_props[:rows].find { |row| row[:category][:slug] == "coding" }
    assert_equal({ n: 5, of: 6 }, home[:ranked])
    assert_equal({ n: 4, of: 6 }, home[:top_tool][:count])
    assert_equal "cursor", home[:top_tool][:item][:slug]
  end

  test "a team viewer reads the team class: tools and models with per-rank names, in ranking order" do
    sign_in_as users(:every_dee)

    get kind_path("coding")

    assert_equal({ show: "team" }, page_props[:filters])
    assert_equal({ slug: "coding", name: "Coding", blurb: "Writing, reviewing, and shipping code." }, page_props[:category])
    assert_equal({ n: 2, of: 2 }, page_props[:ranked])
    assert_equal %w[claude-code cursor], slugs(page_props[:tools]), "two people each, one 1st each, then by name"
    assert_equal({ 1 => [ "Dee Every" ], 2 => [ "Ana Every" ], 3 => [] }, names_by_rank(page_props[:tools].first))
    assert_equal({ 1 => [ "Ana Every" ], 2 => [ "Dee Every" ], 3 => [] }, names_by_rank(listing(page_props[:tools], "cursor")))
    assert_equal %w[claude-opus-5-5 gpt-6-astra], slugs(page_props[:models])
    assert_equal({ n: 2, of: 2 }, page_props[:models].first[:count])
    assert_equal({ 1 => [ "Ana Every", "Dee Every" ], 2 => [], 3 => [] }, names_by_rank(page_props[:models].first))
    assert_equal({ 1 => [], 2 => [ "Dee Every" ], 3 => [] }, names_by_rank(page_props[:models].last))
    assert_nil page_props[:notice]
    assert_not_nil page_props[:last_update_at]
  end

  test "setups group people by tool, model, context and effort" do
    sign_in_as users(:every_dee)

    get kind_path("coding")

    assert_equal(
      [
        [ "claude-code", "claude-opus-5-5", nil, "medium", { n: 1, of: 2 } ],
        [ "cursor", "claude-opus-5-5", "1m", "high", { n: 1, of: 2 } ],
        [ "cursor", "gpt-6-astra", nil, nil, { n: 1, of: 2 } ]
      ],
      page_props[:setups].map { |setup| [ setup[:tool][:slug], setup[:model][:slug], setup[:context], setup[:effort], setup[:count] ] }
    )
  end

  test "a visitor reads only people who share with anyone with the link" do
    get kind_path("coding")

    assert_response :success
    assert_equal({ n: 1, of: 1 }, page_props[:ranked])
    assert_equal({ 1 => [ "Ana Every" ], 2 => [], 3 => [] }, names_by_rank(listing(page_props[:tools], "cursor")))
    assert_equal({ 1 => [], 2 => [ "Ana Every" ], 3 => [] }, names_by_rank(listing(page_props[:tools], "claude-code")))
  end

  test "show=others reads Everyone else" do
    sign_in_as users(:every_dee)

    get kind_path("coding"), params: { show: "others" }

    assert_equal({ show: "others" }, page_props[:filters])
    assert_equal({ n: 2, of: 2 }, page_props[:ranked])
    assert_equal %w[claude-code cursor], slugs(page_props[:tools])
    assert_equal({ 1 => [ "Fay Every" ], 2 => [ "Eli Outside" ], 3 => [] }, names_by_rank(listing(page_props[:tools], "claude-code")))
    assert_equal({ n: 1, of: 2 }, listing(page_props[:tools], "cursor")[:count])
    assert_equal({ 1 => [ "Eli Outside" ], 2 => [], 3 => [] }, names_by_rank(listing(page_props[:tools], "cursor")))
  end

  test "show=subscribers falls back to the team with a notice" do
    sign_in_as users(:every_dee)

    get kind_path("coding"), params: { show: "subscribers" }

    assert_equal({ show: "team" }, page_props[:filters])
    assert_equal Audience::SUBSCRIBERS_NOTICE, page_props[:notice]
    assert_equal({ n: 2, of: 2 }, page_props[:ranked])
  end

  # Unknown and empty kinds

  test "an unknown slug is a 404 for a visitor and a member" do
    get kind_path("nothing-here")
    assert_response :not_found

    sign_in_as users(:every_dee)
    get kind_path("nothing-here")
    assert_response :not_found
  end

  test "a kind nobody ranked renders 200 with empty lists and no zero-of-zero" do
    sign_in_as users(:every_dee)

    get kind_path("video")

    assert_response :success
    assert_equal({ n: 0, of: 2 }, page_props[:ranked])
    assert_equal [ [], [], [], [] ], page_props.values_at(:tools, :models, :setups, :takes)
    assert_nil page_props[:eras]
    assert_not_nil page_props[:cta]
  end

  test "with nobody sharing at all every kind is empty and none reports zero of zero" do
    Entry.delete_all

    get kind_path("coding")

    assert_response :success
    assert_equal({ n: 0, of: 0 }, page_props[:ranked], "the page renders the empty state instead of this count")
    assert_empty page_props[:tools]
    assert_nil page_props[:last_update_at]
  end

  # Takes: link-outs to the Vibe Checks of launched models ranked in this kind

  test "takes are the Vibe Check links of launched models people ranked in the kind" do
    sign_in_as users(:every_dee)

    get kind_path("coding")

    assert_equal [ [ "claude-opus-5-5", "https://checks.every.to/vibe-checks/claude-opus-5-5" ] ], page_props[:takes].map { |take| [ take[:model][:slug], take[:url] ] }
  end

  test "a launched model nobody ranked in the kind gives no take, and a kind with none has an empty list" do
    ai_models(:gpt_6).update!(released_on: 3.days.ago.to_date, vibe_check_url: "https://checks.every.to/vibe-checks/gpt-6-astra")
    sign_in_as users(:every_dee)

    get kind_path("coding")
    assert_equal %w[gpt-6-astra claude-opus-5-5], page_props[:takes].map { |take| take[:model][:slug] }, "newest launch first"

    get kind_path("knowledge-work")
    assert_equal %w[claude-opus-5-5], page_props[:takes].map { |take| take[:model][:slug] }, "only Opus 5.5 is ranked in knowledge work"

    get kind_path("video")
    assert_empty page_props[:takes]
  end

  # AE2: a hidden person is nobody's business

  test "a hidden person is not named, counted or linked for a colleague, and is present for herself" do
    ai_models(:opus_5).update!(vibe_check_url: "https://checks.every.to/vibe-checks/claude-opus-5")
    sign_in_as users(:every_dee)

    get kind_path("coding")

    everything = kind_props.to_json
    assert_not_includes everything, "Cy Every"
    assert_not_includes everything, '"cy"'
    assert_not_includes everything, "claude-opus-5\""
    assert_not_includes everything, "200k", "her context choice is not a setup"

    sign_in_as users(:every_cy)
    get kind_path("coding")

    assert_equal({ n: 3, of: 3 }, page_props[:ranked])
    assert_equal({ 1 => [ "Ana Every", "Cy Every" ], 2 => [ "Dee Every" ], 3 => [] }, names_by_rank(listing(page_props[:tools], "cursor")))
    assert_includes slugs(page_props[:models]), "claude-opus-5"
    assert_includes page_props[:takes].map { |take| take[:model][:slug] }, "claude-opus-5"
  end

  # The call to action follows the viewer

  test "a visitor is asked to sign in to rank the kind" do
    get kind_path("coding")

    assert_equal({ label: "Sign in to rank coding", href: "/toolbox/edit?kind=coding" }, page_props[:cta])
  end

  test "a member with no pick in the kind is asked to rank it, and one with a pick to edit it" do
    sign_in_as newcomer
    get kind_path("knowledge-work")
    assert_equal({ label: "Rank your knowledge work picks", href: "/toolbox/edit?kind=knowledge-work" }, page_props[:cta])

    sign_in_as users(:every_dee)
    get kind_path("coding")
    assert_equal({ label: "Edit your coding picks", href: "/toolbox/edit?kind=coding" }, page_props[:cta])

    get kind_path("video")
    assert_equal({ label: "Rank your video picks", href: "/toolbox/edit?kind=video" }, page_props[:cta])
  end

  test "the call to action link only selects a kind in the editor" do
    sign_in_as users(:every_dee)
    get kind_path("coding")
    cta = page_props[:cta]

    get cta[:href]

    assert_response :success
    assert_inertia_component "toolbox/edit"
    assert_equal "coding", page_props[:selected_kind]
    assert_equal 2, users(:every_dee).entries.where(category: categories(:coding)).count, "visiting the link changed nothing"
  end

  # What we used before

  test "the history section is absent with one era" do
    three_teammates
    watcher = add_person("watcher", visibility: "only_me", team: true)
    assert_equal 1, NumberOneHistory.new(viewer: watcher).eras(categories(:coding)).size, "one era exists, and the page still hides it"
    sign_in_as watcher

    get kind_path("coding")

    assert_response :success
    assert_nil page_props[:eras]
  end

  test "the history section is present with two eras, the last one current" do
    three_teammates
    travel_to Time.utc(2026, 3, 2, 10)
    dan = teammate("dan")
    rank dan, 1, tools(:claude_code)
    sign_in_as add_person("watcher", visibility: "only_me", team: true)

    get kind_path("coding")

    eras = page_props[:eras]
    assert_equal [ "cursor", "claude-code" ], eras.map { |era| era[:tool][:slug] }
    assert_equal [ [ "2026-01-05", "2026-03-01" ], [ "2026-03-02", nil ] ], eras.map { |era| [ era[:from], era[:to] ] }
    assert_equal page_props[:tools].first[:item], eras.last[:tool], "the current era is today's number one"
  end

  test "the history follows the SHOW class" do
    three_teammates
    travel_to Time.utc(2026, 3, 2, 10)
    rank teammate("dan"), 1, tools(:claude_code)
    sign_in_as add_person("watcher", visibility: "only_me", team: true)

    get kind_path("coding"), params: { show: "others" }

    assert_nil page_props[:eras], "nobody in Everyone else ranked before"
  end

  # KTD19 and page meta

  test "responses are private and vary by cookie" do
    sign_in_as users(:every_dee)

    get kind_path("coding")

    assert_never_shared_cacheable
    assert_includes response.headers["Cache-Control"].split(/,\s*/), "must-revalidate"
  end

  test "page meta names the kind and does not depend on who is signed in" do
    get kind_path("coding")
    visitor = preview_meta
    sign_in_as users(:every_cy)
    get kind_path("coding")
    member = preview_meta

    assert_equal visitor, member
    assert_includes member.join, "Coding"
    assert_not_includes member.join, "Cy"
  end
end
