require "test_helper"

# Fixture population (test/fixtures): with confirmed picks are ana and dee (verified
# team), cy (verified team, only me), eli (non-team, link) and fay (unverified
# @every.to, link). one and two have none.
class AudienceTest < ActiveSupport::TestCase
  def handles(audience) = audience.people.pluck(:handle)

  # Viewer class by SHOW: who is in the population, in name order, and so what M is.
  POPULATIONS = {
    nil => { "team" => %w[ana], "others" => %w[eli fay] },
    one: { "team" => %w[ana], "others" => %w[eli fay] },
    outside_eli: { "team" => %w[ana], "others" => %w[eli fay] },
    every_fay: { "team" => %w[ana], "others" => %w[eli fay] },
    every_dee: { "team" => %w[ana dee], "others" => %w[eli fay] },
    every_ana: { "team" => %w[ana dee], "others" => %w[eli fay] },
    every_cy: { "team" => %w[ana cy dee], "others" => %w[eli fay] }
  }.freeze

  POPULATIONS.each do |viewer_name, shows|
    shows.each do |show, expected|
      test "population for #{viewer_name.inspect} with SHOW #{show}" do
        viewer = viewer_name && users(viewer_name)
        audience = Audience.new(viewer:, show:)

        assert_equal expected, handles(audience)
        assert_equal expected.size, audience.size
        assert_equal show, audience.show
        assert_nil audience.notice
      end
    end
  end

  test "the team is the default SHOW and the team plus the rest add up to what fixtures hand-derive" do
    viewer = users(:every_dee)

    assert_equal "team", Audience.new(viewer:).show
    assert_equal 4, Audience.new(viewer:, show: "team").size + Audience.new(viewer:, show: "others").size
  end

  test "an unverified @every.to address is in the rest, not the team" do
    assert_includes handles(Audience.new(viewer: users(:every_dee), show: "others")), "fay"
    assert_not_includes handles(Audience.new(viewer: users(:every_dee), show: "team")), "fay"
  end

  test "AE2: a person who is only me is in nobody's population but their own, with a note for them" do
    cy = users(:every_cy)

    assert_not_includes handles(Audience.new(viewer: users(:every_dee))), "cy"
    assert_not_includes handles(Audience.new(viewer: nil)), "cy"

    own = Audience.new(viewer: cy)
    assert_includes handles(own), "cy"
    assert own.includes_private_picks?
    assert_not Audience.new(viewer: users(:every_dee)).includes_private_picks?
    assert_not Audience.new(viewer: nil).includes_private_picks?
  end

  test "the private-picks note needs the owner to be counted and their picks to be private" do
    cy = users(:every_cy)

    assert_not Audience.new(viewer: cy, show: "others").includes_private_picks?, "cy is not in this SHOW class"

    cy.update!(visibility: "team")
    assert_not Audience.new(viewer: cy).includes_private_picks?, "colleagues see the picks, so nothing is private"

    lone = add_person("lone", visibility: "only_me")
    assert_not Audience.new(viewer: lone, show: "others").includes_private_picks?, "no confirmed picks, so not counted"
    add_pick(lone, :coding, 1, :cursor)
    assert Audience.new(viewer: lone, show: "others").includes_private_picks?
  end

  test "AE2: an unknown person, a hidden person and a person outside the SHOW class behave alike" do
    dee = users(:every_dee)
    unknown = Audience.new(viewer: dee, person: "nobody-here")

    [ "cy", "eli", "one", "Nobody-Here", "", nil, [ "ana" ], { "a" => "b" } ].each do |value|
      audience = Audience.new(viewer: dee, person: value)

      assert_nil audience.person, "person #{value.inspect}"
      assert_equal unknown.filters, audience.filters
      assert_equal unknown.people, audience.people
      assert_equal unknown.size, audience.size
    end
  end

  test "a person in the population can be selected, by handle in any case" do
    audience = Audience.new(viewer: users(:every_dee), person: " ANA ")

    assert_equal users(:every_ana), audience.person
    assert_equal({ show: "team", person: "ana" }, audience.filters)
  end

  test "a person in the other SHOW class is only selectable under that class" do
    assert_nil Audience.new(viewer: users(:every_dee), show: "team", person: "eli").person
    assert_equal users(:outside_eli), Audience.new(viewer: users(:every_dee), show: "others", person: "eli").person
  end

  test "a viewer can select themselves once they are counted" do
    assert_equal users(:every_cy), Audience.new(viewer: users(:every_cy), person: "cy").person
  end

  test "a person the viewer may open but who has no confirmed pick is not counted or selectable" do
    quinn = add_person("quinn", visibility: "team", team: true)
    audience = Audience.new(viewer: users(:every_dee), person: "quinn")

    assert quinn.visible_to?(users(:every_dee))
    assert_not_includes handles(audience), "quinn"
    assert_nil audience.person
    assert_equal 2, audience.size
  end

  test "a person whose only pick is a pending item is not counted until it is approved" do
    ren = add_person("ren", team: true)
    pending = add_tool("Zed Editor", status: "pending", created_by: ren)
    add_pick(ren, :coding, 1, pending)
    dee = users(:every_dee)

    assert_not_includes handles(Audience.new(viewer: dee)), "ren"
    assert_not_includes handles(Audience.new(viewer: ren)), "ren", "not even for the owner: aggregates only see approved items"

    pending.update!(status: "approved")
    assert_includes handles(Audience.new(viewer: dee)), "ren"
  end

  test "SHOW subscribers falls back to the team with a notice; unknown values fall back without one" do
    assert_not Audience::SUBSCRIBERS_AVAILABLE

    audience = Audience.new(viewer: users(:every_dee), show: "subscribers")
    assert_equal "team", audience.show
    assert_equal({ show: "team", person: nil }, audience.filters)
    assert_equal %w[ana dee], handles(audience)
    assert_match(/subscribers/i, audience.notice)

    [ "everyone", "", nil, "TEAM ", [ "others" ] ].each do |value|
      fallback = Audience.new(viewer: users(:every_dee), show: value)
      assert_equal "team", fallback.show, "show #{value.inspect}"
      assert_nil fallback.notice
    end
  end

  test "PERSON options carry a handle and a name only, in name order" do
    audience = Audience.new(viewer: users(:every_cy))

    assert_equal [ { handle: "ana", name: "Ana Every" }, { handle: "cy", name: "Cy Every" }, { handle: "dee", name: "Dee Every" } ], audience.people
    assert_no_private_fields audience.people
  end

  test "an empty population is empty, with no people" do
    Entry.delete_all
    audience = Audience.new(viewer: users(:every_dee))

    assert audience.empty?
    assert_equal 0, audience.size
    assert_empty audience.people
  end

  test "the levels a viewer may read come from the visibility rule" do
    assert_equal %w[link], Audience.new(viewer: nil).levels
    assert_equal %w[link], Audience.new(viewer: users(:outside_eli)).levels
    assert_equal %w[team link], Audience.new(viewer: users(:every_dee)).levels
    assert_equal %w[link], Audience.new(viewer: users(:every_fay)).levels
  end

  test "the one comparator orders by people, then first picks, then name" do
    rows = [ [ 2, 1, "Zed" ], [ 3, 0, "Yak" ], [ 2, 2, "Yak" ], [ 2, 1, "abe" ], [ 2, 1, "Mia" ] ]

    assert_equal [ [ 3, 0, "Yak" ], [ 2, 2, "Yak" ], [ 2, 1, "abe" ], [ 2, 1, "Mia" ], [ 2, 1, "Zed" ] ],
      rows.sort_by { |count, firsts, name| Audience.sort_key(count, firsts, name) }
  end

  test "the population is the same for a viewer whatever hidden people do" do
    before = Audience.new(viewer: users(:every_dee))
    snapshot = [ before.people, before.size, before.filters ]

    users(:every_cy).update!(visibility: "team")
    users(:every_cy).update!(visibility: "only_me")
    add_pick(users(:every_cy), :video, 1, :runway)

    after = Audience.new(viewer: users(:every_dee))
    assert_equal snapshot, [ after.people, after.size, after.filters ]
  end
end
