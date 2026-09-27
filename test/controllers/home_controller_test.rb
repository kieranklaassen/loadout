require "test_helper"

# Home is the same page for everyone, read as the viewer. Expectations come from the
# fixture facts in test/fixtures/users.yml and entries.yml: the Every team class holds
# ana and dee for a team viewer (M = 2), ana alone for a visitor (M = 1), and cy joins
# herself when she is signed in (M = 3) although she is only me.
class HomeControllerTest < ActionDispatch::IntegrationTest
  def props = inertia.props.deep_symbolize_keys
  def coding_row = props[:rows].find { |row| row[:category][:slug] == "coding" }

  def partial_search(query, **params)
    get root_path, params: params.merge(q: query), headers: {
      "X-Inertia" => "true",
      "X-Inertia-Version" => InertiaRails.configuration.version.to_s,
      "X-Inertia-Partial-Component" => "home/index",
      "X-Inertia-Partial-Data" => "search"
    }
  end

  # The signed-in member who has finished onboarding but ranked nothing.
  def newcomer
    users(:one).tap { |user| user.update!(handle: "newcomer", name: "New Comer", onboarded_at: Time.current) }
  end

  # AE6

  test "nobody having shared shows the empty state, no hero and no zero-of-zero" do
    Entry.delete_all

    get root_path

    assert_response :success
    assert_inertia_component "home/index"
    assert_equal "nobody_shared", props[:empty_reason]
    assert_nil props[:hero]
    assert_empty props[:rows]
    assert_equal({ label: "Join Every", href: LoadoutHost::JOIN_EVERY_URL }, props[:cta])
    refute_includes props.slice(:rows, :hero, :overall).to_json, '"of":0'
  end

  # Signed-in members stay on Home

  test "a signed-in member is no longer redirected from Home" do
    sign_in_as users(:every_ana)

    get root_path

    assert_response :success
    assert_inertia_component "home/index"
  end

  test "a member who has not finished onboarding still goes to onboarding" do
    sign_in_as users(:one)

    get root_path

    assert_redirected_to "/welcome"
  end

  # AE1 and AE2: the same M for the same viewer, and nobody hidden anywhere

  test "a team viewer reads the team class: two people, counts out of two" do
    sign_in_as users(:every_dee)

    get root_path

    assert_equal({ show: "team", person: nil, overall: false, q: nil }, props[:filters])
    assert_equal [ "Ana Every", "Dee Every" ], props[:people].map { |person| person[:name] }
    assert_equal({ n: 2, of: 2 }, coding_row[:ranked])
    assert_equal [ "claude-code", "cursor" ], [ coding_row[:top_tool][:item][:slug], coding_row[:top_tool][:runner_up][:item][:slug] ]
    assert_equal({ n: 2, of: 2 }, coding_row[:top_tool][:count])
    assert_equal({ n: 2, of: 2 }, coding_row[:top_model][:count])
  end

  test "a visitor reads only people who share with anyone with the link" do
    get root_path

    assert_equal [ "ana" ], props[:people].map { |person| person[:handle] }
    assert_equal({ n: 1, of: 1 }, coding_row[:ranked])
    assert_nil props[:person]
  end

  test "Everyone else lists the rest of the visible people and switching SHOW switches the counts" do
    sign_in_as users(:every_dee)

    get root_path, params: { show: "others" }

    assert_equal "others", props[:filters][:show]
    assert_equal [ "Eli Outside", "Fay Every" ], props[:people].map { |person| person[:name] }
    assert_equal({ n: 2, of: 2 }, coding_row[:ranked])
  end

  test "a hidden person is missing from counts and people for a colleague, and present for herself" do
    sign_in_as users(:every_dee)
    get root_path
    everything = props.slice(:people, :rows, :hero, :overall, :launches).to_json
    refute_includes everything, "Cy Every"
    refute_includes everything, '"Claude Opus 5"', "her private model must not count for a colleague"

    sign_in_as users(:every_cy)
    get root_path

    assert_includes props[:people].map { |person| person[:handle] }, "cy"
    assert_equal({ n: 3, of: 3 }, coding_row[:ranked])
    assert_equal true, props[:private_picks]
  end

  test "the private-picks note is off for someone who shares" do
    sign_in_as users(:every_dee)

    get root_path

    assert_equal false, props[:private_picks]
  end

  test "a hidden handle behaves exactly like an unknown handle" do
    sign_in_as users(:every_dee)

    get root_path, params: { person: "cy" }
    hidden = props
    get root_path, params: { person: "nobody-here" }

    assert_equal props, hidden
    assert_nil hidden[:person]
    assert_nil hidden[:filters][:person]
    assert_not_nil hidden[:hero]
  end

  test "the visitor sees the same not-a-person response for a team-only handle" do
    get root_path, params: { person: "dee" }
    team_only = props
    get root_path

    assert_equal props, team_only
  end

  # Person view

  test "person= opens that person's picks, drops the hero and lists Team uses only where they differ" do
    sign_in_as users(:every_dee)

    get root_path, params: { person: "ana" }

    person = props[:person]
    assert_equal "ana", props[:filters][:person]
    assert_equal({ handle: "ana", name: "Ana Every", avatar_url: "https://every.to/avatars/ana.png" }, person[:person])
    assert_equal 2, person[:ranked_count]
    assert_equal 3, person[:kinds].size, "every kind is listed, ranked or not"
    assert_nil props[:hero]
    coding = person[:kinds].find { |kind| kind[:category][:slug] == "coding" }
    assert_equal %w[cursor claude-code], coding[:picks].map { |pick| pick[:tool][:slug] }
    assert_equal "claude-code", coding[:team_uses][:tool][:slug], "her first pick is not the team's most used tool"
    assert_nil coding[:team_uses][:model], "her model is the team's most used, so no note"
    assert_nil person[:kinds].find { |kind| kind[:category][:slug] == "knowledge-work" }[:team_uses]
    assert_equal [ "claude-opus-5-5" ], person[:new_in_loadout].map { |launch| launch[:model][:slug] }
  end

  test "a person in the other SHOW class is not opened" do
    sign_in_as users(:every_dee)

    get root_path, params: { person: "ana", show: "others" }

    assert_nil props[:person]
    assert_nil props[:filters][:person]
  end

  # AE5

  test "launches list only models with a date and a valid Vibe Check link, newest marked" do
    get root_path

    launches = props[:launches]
    assert_equal [ "claude-opus-5-5" ], launches.map { |launch| launch[:model][:slug] }
    assert_equal "https://checks.every.to/vibe-checks/claude-opus-5-5", launches.first[:vibe_check_url]
    assert launches.first[:newest]
    assert_equal LoadoutHost::ALL_VIBE_CHECKS_URL, props[:all_vibe_checks_url]
  end

  # SHOW stub

  test "show=subscribers falls back to the team with a notice" do
    get root_path, params: { show: "subscribers" }

    assert_equal "team", props[:filters][:show]
    assert_equal Audience::SUBSCRIBERS_NOTICE, props[:notice]
  end

  test "no notice on a normal visit" do
    get root_path

    assert_nil props[:notice]
  end

  test "overall=1 is echoed and the overall lists carry the same counts" do
    sign_in_as users(:every_dee)

    get root_path, params: { overall: "1" }

    assert_equal true, props[:filters][:overall]
    tools = props[:overall][:tools]
    assert_equal({ n: 2, of: 2 }, tools.find { |entry| entry[:item][:slug] == "claude-code" }[:count])
    assert_equal({ n: 2, of: 2 }, tools.find { |entry| entry[:item][:slug] == "claude" }[:count])
  end

  # The call to action follows the viewer

  test "the call to action is Join Every for a visitor" do
    get root_path

    assert_equal({ label: "Join Every", href: "https://every.to" }, props[:cta])
  end

  test "a signed-in member with nothing ranked is asked to rank their first tools" do
    sign_in_as newcomer

    get root_path

    assert_equal({ label: "Rank your first tools", href: "/loadout/edit" }, props[:cta])
  end

  test "a signed-in member with confirmed picks gets no call to action" do
    sign_in_as users(:every_dee)

    get root_path

    assert_nil props[:cta]
  end

  # KTD19

  test "responses are private and vary by cookie" do
    sign_in_as users(:every_dee)

    get root_path

    assert_includes response.headers["Cache-Control"].split(/,\s*/), "private"
    assert_not_includes response.headers["Cache-Control"], "public"
    assert_includes response.headers["Vary"].split(/,\s*/), "Cookie"
  end

  test "page meta does not depend on who is signed in" do
    get root_path
    visitor = css_select("meta[name=description], meta[property='og:description'], meta[property='og:title']").map(&:to_s)
    sign_in_as users(:every_cy)
    get root_path
    member = css_select("meta[name=description], meta[property='og:description'], meta[property='og:title']").map(&:to_s)

    assert_equal visitor, member
    assert_not_includes member.join, "Cy"
  end

  # Search (an optional prop, asked for by a partial reload)

  test "search is left out of a full page load, which still echoes the cleaned query" do
    get root_path, params: { q: "  cursor  " }

    assert_not props.key?(:search)
    assert_equal "cursor", props[:filters][:q]
  end

  test "a partial reload returns people and items the viewer may see, with N of M" do
    sign_in_as users(:every_dee)

    partial_search "cur"

    search = response.parsed_body["props"]["search"]
    assert_equal "cur", search["query"]
    assert_empty search["people"]
    cursor = search["items"].find { |hit| hit["item"]["slug"] == "cursor" }
    assert_equal "tool", cursor["kind"]
    assert_equal [ { "category" => categories(:coding).to_prop.stringify_keys, "count" => { "n" => 2, "of" => 2 } } ], cursor["kinds"]
  end

  test "search finds a visible person by name and never a hidden one" do
    sign_in_as users(:every_dee)

    partial_search "Every"
    assert_equal %w[ana dee], response.parsed_body["props"]["search"]["people"].map { |person| person["handle"] }.sort

    partial_search "Cy"
    assert_empty response.parsed_body["props"]["search"]["people"]
  end

  test "search under two characters finds nothing" do
    partial_search "c"

    search = response.parsed_body["props"]["search"]
    assert_equal({ "query" => "c", "people" => [], "items" => [] }, search)
  end

  test "search keeps the current SHOW class" do
    sign_in_as users(:every_dee)

    partial_search "Eli", show: "others"

    assert_equal [ "eli" ], response.parsed_body["props"]["search"]["people"].map { |person| person["handle"] }
  end

  test "requests that carry q are rate limited per IP, other requests are not" do
    120.times { get root_path, params: { q: "cursor" } }
    assert_response :success

    get root_path, params: { q: "cursor" }
    assert_response :too_many_requests

    get root_path
    assert_response :success
  end
end
