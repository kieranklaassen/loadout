require "test_helper"

# AE10, R12, R13: whatever a hidden person does, nobody else can tell. Cy is only me, with a
# past team period. For each viewer class this reads Home, the Kind pages (with the team's
# "What we used before"), a visible person's Profile, Cy's own handle, search results and the
# agent tools, then changes Cy's picks, suggestions, visibility, pending catalog items, account and
# finally deletes her, and requires that what every other viewer sees stays byte-identical.
#
# Time is frozen, so timestamps such as a kind's last update are compared exactly: they are
# one of the ways a hidden edit could show, so they are not normalised away. A person's
# own view (Cy's) is left out of the comparison, except to show that it does change.
class HiddenPersonInvarianceTest < ActionDispatch::IntegrationTest
  include SurfaceHelper

  SHOWS = %w[team others].freeze
  KINDS = %w[coding knowledge-work video].freeze
  SEARCHES = [ "cy", "cy every", "opus", "secret", "cursor", "runway" ].freeze
  PROFILES = %w[/ana /dee /eli /cy /nobody-here].freeze

  setup do
    @now = Time.current.change(usec: 0)
    @cy = users(:every_cy)
    build_team_history
    @viewers = {
      "a visitor" => nil,
      "a signed-in member outside Every" => add_person("newcomer", visibility: "only_me"),
      "a verified Every member" => users(:every_dee),
      "another Every member whose picks are private" => @dot
    }
  end

  # Reads only, and a mutation changes nothing that a snapshot has not seen

  test "reading twice gives the same answer, so a difference later is a change" do
    assert_equal read_everyone, read_everyone
  end

  test "the team has a history of its own for Cy's past to disturb" do
    sign_in_as users(:every_dee)
    get kind_path("coding")

    assert_operator page_props[:eras].to_a.size, :>=, 2
    assert_equal 5, page_props[:ranked][:of], "ana, dee, gil, hal and ivy; not Cy"
  end

  # AE10

  test "AE10: her picks, suggestions, visibility, pending items, account and deletion change nothing for anyone else" do
    baseline = read_everyone
    herself = read_as(@cy)

    mutate(baseline, "she changes her picks") do
      update_loadout @cy, [
        { op: "set_pick", category: "coding", rank: 1, tool: "claude-code", model: "claude-opus-5-5", context: "1m", effort: "high" },
        { op: "set_pick", category: "coding", rank: 2, tool: "cursor" },
        { op: "set_pick", category: "video", rank: 1, tool: "runway" },
        { op: "set_pick", category: "knowledge-work", rank: 1, tool: "claude" }
      ]
    end
    assert_not_equal herself, read_as(@cy), "her own page shows her change, so the snapshot can see it"

    mutate(baseline, "an agent suggests picks for her") do
      update_loadout @cy, [ { op: "suggest", category: "knowledge-work", tool: "claude-code", model: "claude-opus-5-5" }, { op: "suggest", category: "video", tool: "Cy Agent Tool" } ],
        source: "mcp", client_name: "Claude", oauth_client_id: 7
    end

    mutate(baseline, "she shares with the Every team, then with the link, then stops again") do
      @cy.update!(visibility: "team")
      travel 1.minute
      assert_not_equal baseline["a verified Every member"], read_as(users(:every_dee)), "the team sees her while she shares with it"
      @cy.update!(visibility: "link")
      travel 1.minute
      assert_not_equal baseline["a visitor"], read_as(nil), "a visitor sees her while she shares with the link"
      @cy.update!(visibility: "only_me")
    end

    mutate(baseline, "she adds pending catalog items and ranks them") do
      Tool.resolve_or_suggest!("Cy Secret Tool", user: @cy)
      AiModel.resolve_or_suggest!("Cy Secret Model", user: @cy)
      update_loadout @cy, [ { op: "set_pick", category: "coding", rank: 3, tool: "Cy Secret Tool", model: "Cy Secret Model" } ]
    end

    mutate(baseline, "she removes a pick") do
      update_loadout @cy, [ { op: "remove_pick", category: "coding", rank: 1 } ]
    end

    mutate(baseline, "she renames herself and changes her handle and bio") do
      @cy.update!(name: "Cynthia Renamed", handle: "cy-renamed", bio: "Now writing about Zed.")
    end

    mutate(baseline, "her account is deleted") do
      @cy.destroy!
    end
  end

  # The snapshot is not blind

  test "were Cy to share with the team again, her past team period would change the team's history" do
    sign_in_as users(:every_dee)
    get kind_path("coding")
    hidden = page_props[:eras]

    travel 1.minute
    @cy.update!(visibility: "team")
    get kind_path("coding")

    assert_not_equal hidden, page_props[:eras]
  end

  test "a visible person's change is seen by every viewer class that can open her" do
    before = read_everyone

    travel 1.minute
    update_loadout users(:every_ana), [ { op: "set_pick", category: "coding", rank: 3, tool: "runway" } ]
    after = read_everyone

    @viewers.each_key { |viewer| assert_not_equal before[viewer], after[viewer], "#{viewer} sees a change by a person who shares with the link" }
  end

  test "a team-only person's change reaches the team and nobody else" do
    before = read_everyone

    travel 1.minute
    update_loadout users(:every_dee), [ { op: "set_pick", category: "coding", rank: 3, tool: "runway" } ]
    after = read_everyone

    assert_equal before["a visitor"], after["a visitor"]
    assert_equal before["a signed-in member outside Every"], after["a signed-in member outside Every"]
    assert_not_equal before["another Every member whose picks are private"], after["another Every member whose picks are private"]
  end

  private

  # Three more teammates join 100 days ago, so the team has a history of its own: Zed leads
  # until Gil switches to Claude Code 25 days ago. Cy's team period (100 to 50 days ago, see
  # visibility_periods.yml) overlaps all of it, and she would change the eras if she counted.
  # Dot is another hidden Every member, with private picks of her own.
  def build_team_history
    zed = add_tool("Zed")
    windsurf = add_tool("Windsurf")

    travel_to @now - 100.days
    gil, hal, ivy = %w[gil hal ivy].map { |handle| add_person(handle, visibility: "team", team: true) }
    @dot = add_person("dot", visibility: "only_me", team: true)
    update_loadout gil, [ { op: "set_pick", category: "coding", rank: 1, tool: zed.slug } ]
    update_loadout hal, [ { op: "set_pick", category: "coding", rank: 1, tool: zed.slug } ]
    update_loadout ivy, [ { op: "set_pick", category: "coding", rank: 1, tool: windsurf.slug } ]
    update_loadout @dot, [ { op: "set_pick", category: "coding", rank: 1, tool: "cursor", model: "claude-opus-5" } ]

    travel_to @now - 25.days
    update_loadout gil, [ { op: "set_pick", category: "coding", rank: 1, tool: "claude-code" } ]

    travel_to @now
  end

  def update_loadout(user, operations, source: "web", **agent)
    Loadouts::Update.call(user:, source:, operations:, **agent)
  end

  # Runs the change, then requires everyone else's view to be what it was.
  def mutate(baseline, label)
    travel 1.minute
    yield
    travel 1.minute
    after = read_everyone

    baseline.each do |viewer, surfaces|
      changed = surfaces.keys.reject { |surface| surfaces[surface] == after.fetch(viewer)[surface] }
      first = changed.first
      assert_empty changed, "#{label} changed what #{viewer} sees on #{changed.join(", ")}: #{first && difference(surfaces[first], after.fetch(viewer)[first])}"
    end
  end

  # The first place two snapshots differ, for a failure message.
  def difference(before, after)
    at = (0...[ before.size, after.size ].min).find { |index| before[index] != after[index] } || [ before.size, after.size ].min
    "…#{before[[ at - 80, 0 ].max, 200]}… became …#{after[[ at - 80, 0 ].max, 200]}…"
  end

  def read_everyone
    @viewers.transform_values { |viewer| read_as(viewer) }
  end

  # Every surface the issue names, read as one viewer (nil for a visitor): surface => exact text.
  def read_as(viewer)
    HomeController::RATE_LIMIT_STORE.clear
    sign_in_or_out(viewer)
    surfaces = {}

    SHOWS.each do |show|
      surfaces["Home, #{show}"] = read_page(root_path, show:)
      %w[ana cy].each { |handle| surfaces["Home, #{show}, person #{handle}"] = read_page(root_path, show:, person: handle) }
      KINDS.each { |slug| surfaces["Kind #{slug}, #{show}"] = read_page(kind_path(slug), show:) }
      SEARCHES.each { |query| surfaces["search #{query.inspect}, #{show}"] = partial_search(query, show:).to_json }
    end
    PROFILES.each { |path| surfaces["Profile #{path}"] = read_page(path) }
    surfaces.merge!(read_tools(viewer)) if viewer
    surfaces
  end

  # Status, component, every prop and the link-preview tags.
  def read_page(path, **params)
    get path, params: params
    [ response.status, inertia.component, page_props.to_json, preview_meta ].to_json
  end

  def read_tools(viewer)
    calls = SHOWS.flat_map do |show|
      [ [ "get_team_rankings", { audience: show } ] ] + KINDS.map { |slug| [ "get_team_rankings", { audience: show, category: slug } ] }
    end
    calls += [ [ "get_my_loadout", {} ], [ "get_recent_changes", {} ], [ "list_categories", {} ], [ "search_catalog", { query: "secret" } ], [ "search_catalog", { query: "cursor" } ] ]

    calls.to_h { |name, arguments| [ "tool #{name} #{arguments.to_json}", tool_result(viewer, name, arguments).to_json ] }
  end
end
