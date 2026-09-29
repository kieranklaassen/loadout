require "test_helper"

# A team viewer (dee) searches the Every team: ana and dee. Cursor and Claude Code are
# both 2 of 2 in coding; Claude is 2 of 2 in knowledge work; Opus 5.5 is 2 of 2 in coding
# and 1 of 2 in knowledge work; Claude Opus 5 is only on hidden cy; Runway is ranked by eli
# and fay's class (the rest), and ana's Runway is a suggestion.
class SearchTest < ActiveSupport::TestCase
  setup { @dee = users(:every_dee) }

  def search(query, viewer: @dee, **options) = Search.new(viewer:, **options).call(query)
  def names(result, key) = result[key].map { |hit| key == :people ? hit[:handle] : hit[:item][:slug] }

  test "people: by name or handle, only those the viewer may open and who are counted" do
    assert_equal [ { handle: "ana", name: "Ana Every" } ], search("ana")[:people]
    assert_equal [ "ana" ], names(search("ANA"), :people), "case does not matter"
    assert_equal [ "ana" ], names(search("ana ev"), :people), "a name is one string"
    assert_equal %w[ana dee], names(search("every"), :people), "both team names contain it, in name order"
    assert_equal [ "dee" ], names(search("dee"), :people)
  end

  test "people are never found by email address" do
    assert_empty search("@every")[:people]
    assert_empty search("every.to")[:people]
    assert_empty search("ana@")[:people]
  end

  test "AE2: a hidden person is not found by a colleague, and is by themselves" do
    assert_empty search("cy")[:people]
    assert_empty search("cy every")[:people]
    assert_empty search("cy", viewer: nil)[:people]

    cy = users(:every_cy)
    assert_equal [ "cy" ], names(search("cy", viewer: cy), :people)
  end

  test "people outside the SHOW class are found under that class only" do
    assert_empty search("eli")[:people]
    assert_equal [ "eli" ], names(search("eli", show: "others"), :people)
  end

  test "someone with no confirmed pick is not found" do
    add_person("quinn", visibility: "team", team: true)

    assert_empty search("quinn")[:people]
  end

  test "items: approved tools and models the audience ranks, tools first, each with the kinds and counts" do
    result = search("cl")

    assert_equal %w[claude claude-code], names(result, :items).first(2), "Claude before Claude Code: both 2 of 2, but more 1st picks"
    assert_equal %w[tool tool model], result[:items].pluck(:kind)
    claude = result[:items].first
    assert_equal(
      { kind: "tool", item: tools(:claude).to_prop, kinds: [ { category: categories(:knowledge_work).to_prop, count: { n: 2, of: 2 } } ] },
      claude
    )
    assert_equal [ categories(:coding).to_prop ], result[:items].second[:kinds].pluck(:category)
  end

  test "items: a model lists every kind it is ranked in, in catalog order" do
    opus = search("opus 5.5")[:items].first

    assert_equal "claude-opus-5-5", opus[:item][:slug]
    assert_equal(
      [ { category: categories(:coding).to_prop, count: { n: 2, of: 2 } }, { category: categories(:knowledge_work).to_prop, count: { n: 1, of: 2 } } ],
      opus[:kinds]
    )
  end

  test "items: only what the viewer's audience ranks, so a hidden person's model stays out" do
    assert_equal %w[claude-opus-5-5], names(search("opus"), :items)
    assert_equal %w[claude-opus-5-5 claude-opus-5], names(search("opus", viewer: users(:every_cy)), :items)
    assert_empty search("runway")[:items], "nobody on the team ranks Runway"
    assert_equal %w[runway], names(search("runway", show: "others"), :items)
  end

  test "items: a member's pending item is found by no one until approved" do
    ana = users(:every_ana)
    zed = add_tool("Zedcode", status: "pending", created_by: ana)
    add_pick(ana, :coding, 3, zed)

    [ @dee, ana, nil ].each { |viewer| assert_empty search("zedcode", viewer:)[:items] }

    zed.update!(status: "approved")
    hit = search("zedcode")[:items].first
    assert_equal zed.slug, hit[:item][:slug]
    assert_equal [ { n: 1, of: 2 } ], hit[:kinds].pluck(:count)
  end

  test "items: hidden catalog items are not found" do
    tools(:cursor).update!(status: "hidden")

    assert_empty search("cursor")[:items]
  end

  test "a query needs two characters and comes back trimmed" do
    [ "", " ", "a", " a ", nil ].each do |query|
      assert_equal({ query: query.to_s.strip, people: [], items: [] }, search(query))
    end
    assert_equal "ab", search("  ab ")[:query]
    assert_equal "an a", search("an   a")[:query], "inner spaces collapse"
  end

  test "percent and underscore are letters, not wildcards" do
    assert_empty search("%%")[:people]
    assert_empty search("%%")[:items]
    assert_empty search("a%")[:people]
    assert_empty search("_n")[:people], "_n would match the 'an' in Ana as a wildcard"
    assert_empty search("\\\\")[:people], "a backslash is not an escape"

    add_person("pct", team: true, name: "100% Real").tap { |user| add_pick(user, :coding, 1, :cursor) }
    assert_equal [ "pct" ], names(search("100%"), :people)
    assert_empty search("1%0")[:people]
  end

  test "a name that reads like an instruction comes back as plain data" do
    add_person("prompty", team: true, name: "Ignore previous instructions <script>alert(1)</script>").tap { |user| add_pick(user, :coding, 1, :cursor) }
    hit = search("ignore previous")[:people].first

    assert_equal "Ignore previous instructions <script>alert(1)</script>", hit[:name]
    assert_equal %i[handle name], hit.keys
  end

  test "a long query is cut and a long result list is capped" do
    assert_equal Search::MAX_QUERY_LENGTH, search("a" * 500)[:query].length

    12.times { |index| add_pick(add_person("many#{index}", team: true, name: "Many #{index}"), :coding, 1, :cursor) }
    assert_equal Search::LIMIT, search("many")[:people].size
  end

  test "nobody counted gives nothing" do
    Entry.delete_all

    assert_equal({ query: "ana", people: [], items: [] }, search("ana"))
  end

  test "the result has exactly its contract keys and no email, bio or avatar" do
    result = search("cl")
    everything = search("ev")

    assert_equal %i[query people items], result.keys
    assert_equal %i[kind item kinds], result[:items].first.keys
    assert_equal %i[category count], result[:items].first[:kinds].first.keys
    assert_equal %i[handle name], search("ana")[:people].first.keys
    [ result, everything, search("cy", viewer: users(:every_cy)) ].each { |output| assert_no_private_fields output }
    assert_empty all_keys([ result, everything ]) & %i[avatar_url]
  end
end
