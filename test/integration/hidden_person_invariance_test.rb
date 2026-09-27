require "test_helper"

# AE10, R12, R13: whatever a hidden person does, nobody else can tell. Two people are hidden
# and each once shared: Cy, an Every member with a past team period, and Otto, someone
# outside Every with a past link period. For each viewer class this reads Home, the Kind pages
# (with "What we used before"), a visible person's Profile, the hidden person's own handle,
# search results and the agent tools. Then the hidden person changes their picks, suggestions,
# visibility, pending catalog items and account, and is finally deleted; what every other
# viewer sees must stay byte-identical throughout.
#
# Time is frozen, so timestamps such as a kind's last update are compared exactly: they are
# one of the ways a hidden edit could show, so they are not normalised away. The hidden
# person's own view is left out of the comparison, except to show that it does change.
class HiddenPersonInvarianceTest < ActionDispatch::IntegrationTest
  include SurfaceHelper

  SHOWS = %w[team others].freeze
  KINDS = %w[coding knowledge-work video].freeze
  SEARCHES = [ "cy", "otto", "opus", "secret", "cursor", "runway" ].freeze
  PROFILES = %w[/ana /dee /eli /cy /otto /nobody-here].freeze

  # handle => the viewer and SHOW class whose history the person's past would land in
  SUBJECTS = {
    "cy" => { about: "an Every member whose team period is in the past", history: [ "dee", "team" ] },
    "otto" => { about: "someone outside Every whose link period is in the past", history: [ "newcomer", "others" ] }
  }.freeze

  setup do
    @now = Time.current.change(usec: 0)
    build_histories
    @viewers = {
      "a visitor" => nil,
      "a signed-in member outside Every" => User.find_by!(handle: "newcomer"),
      "a verified Every member" => users(:every_dee),
      "another Every member whose picks are private" => User.find_by!(handle: "dot")
    }
  end

  # Reads only, and a mutation changes nothing that a snapshot has not seen

  test "reading twice gives the same answer, so a difference later is a change" do
    assert_equal read_everyone, read_everyone
  end

  SUBJECTS.each do |handle, subject|
    test "the history has two eras of its own for #{handle}'s past to disturb" do
      viewer, show = subject[:history]
      sign_in_as User.find_by!(handle: viewer)
      get kind_path("coding"), params: { show: }

      assert_operator page_props[:eras].to_a.size, :>=, 2
      assert_equal 5, page_props[:ranked][:of], "the five other people in the class, not #{handle}"
    end

    test "were #{handle} to share again, their past period would change the history" do
      viewer, show = subject[:history]
      sign_in_as User.find_by!(handle: viewer)
      get kind_path("coding"), params: { show: }
      hidden = page_props[:eras]

      travel 1.minute
      User.find_by!(handle:).update!(visibility: "link")
      get kind_path("coding"), params: { show: }

      assert_not_equal hidden, page_props[:eras]
    end

    test "AE10: #{handle} (#{subject[:about]}): picks, suggestions, visibility, pending items, account and deletion change nothing for anyone else" do
      person = User.find_by!(handle:)
      baseline = read_everyone
      themselves = read_as(person)

      mutate(baseline, "they change their picks") do
        update_loadout person, [
          { op: "set_pick", category: "coding", rank: 1, tool: "claude-code", model: "claude-opus-5-5", context: "1m", effort: "high" },
          { op: "set_pick", category: "coding", rank: 2, tool: "cursor" },
          { op: "set_pick", category: "video", rank: 1, tool: "runway" },
          { op: "set_pick", category: "knowledge-work", rank: 1, tool: "claude" }
        ]
      end
      assert_not_equal themselves, read_as(person), "their own page shows the change, so the snapshot can see it"

      mutate(baseline, "an agent suggests picks for them") do
        update_loadout person, [ { op: "suggest", category: "knowledge-work", tool: "claude-code", model: "claude-opus-5-5" }, { op: "suggest", category: "video", tool: "Secret Agent Tool" } ],
          source: "mcp", client_name: "Claude", oauth_client_id: 7
      end

      mutate(baseline, "they share with the Every team, then with the link, then stop again") do
        person.update!(visibility: "team")
        travel 1.minute
        assert_not_equal baseline["a verified Every member"], read_as(users(:every_dee)), "the team sees them while they share with it"
        person.update!(visibility: "link")
        travel 1.minute
        assert_not_equal baseline["a visitor"], read_as(nil), "a visitor sees them while they share with the link"
        person.update!(visibility: "only_me")
      end

      mutate(baseline, "they add pending catalog items and rank them") do
        Tool.resolve_or_suggest!("Secret Tool", user: person)
        AiModel.resolve_or_suggest!("Secret Model", user: person)
        update_loadout person, [ { op: "set_pick", category: "coding", rank: 3, tool: "Secret Tool", model: "Secret Model" } ]
      end

      mutate(baseline, "they remove a pick") do
        update_loadout person, [ { op: "remove_pick", category: "coding", rank: 1 } ]
      end

      mutate(baseline, "they rename themselves and change their handle and bio") do
        person.update!(name: "Renamed Person", handle: "#{handle}-renamed", bio: "Now writing about Zed.")
      end

      mutate(baseline, "their account is deleted") do
        person.destroy!
      end
    end
  end

  # The snapshot is not blind

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

  # Each class has, besides the fixture people, three members who joined 100 days ago and a
  # history of their own: Zed leads until one of them switches to Claude Code 25 days ago.
  # The hidden person's past sharing period (Cy: fixtures, 100 to 50 days ago; Otto: made here,
  # the same span) overlaps all of it, and would change the eras if they counted.
  # Dot is another hidden Every member, with private picks of her own.
  def build_histories
    zed = add_tool("Zed")
    windsurf = add_tool("Windsurf")

    travel_to @now - 100.days
    add_person("newcomer", visibility: "only_me")
    dot = add_person("dot", visibility: "only_me", team: true)
    otto = add_person("otto", visibility: "link")
    [ [ %w[gil hal ivy], { visibility: "team", team: true } ], [ %w[pam quinn rae], { visibility: "link", team: false } ] ].each do |handles, options|
      first, second, third = handles.map { |handle| add_person(handle, **options) }
      update_loadout first, [ { op: "set_pick", category: "coding", rank: 1, tool: zed.slug } ]
      update_loadout second, [ { op: "set_pick", category: "coding", rank: 1, tool: zed.slug } ]
      update_loadout third, [ { op: "set_pick", category: "coding", rank: 1, tool: windsurf.slug } ]
    end
    update_loadout dot, [ { op: "set_pick", category: "coding", rank: 1, tool: "cursor", model: "claude-opus-5" } ]
    update_loadout otto, [ { op: "set_pick", category: "coding", rank: 1, tool: "cursor", model: "gpt-6-astra" } ]

    travel_to @now - 50.days
    otto.update!(visibility: "only_me")

    travel_to @now - 25.days
    %w[gil pam].each { |handle| update_loadout User.find_by!(handle:), [ { op: "set_pick", category: "coding", rank: 1, tool: "claude-code" } ] }

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
      %w[ana cy otto].each { |handle| surfaces["Home, #{show}, person #{handle}"] = read_page(root_path, show:, person: handle) }
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
