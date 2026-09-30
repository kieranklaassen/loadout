require "test_helper"

# AE1, AE2, R13, R15: every surface counts and names the same people. For each viewer class
# and each SHOW class, Home, the Kind pages, search and the get_team_rankings tool are read as
# the same member and must agree on who is counted (M), on every N of M and on the people they
# name. Two sets: the named people are the ones the viewer may open, and only they are ever
# named, offered as PERSON or found by search; the counted people are who every number is
# over. On the team that is every onboarded member with a pick, whatever they share, so a
# private or team-only member counts for a visitor too but is named nowhere; outside the team
# the two sets are the same. A person the viewer may not open has a profile and share card
# that are the same not-found as a handle nobody claimed.
#
# Expectations come from the table of people below and the visibility rule written out
# longhand, never from the read layer. The tool is a member-only transport, so a visitor is
# held to the pages and the oracle alone.
class SurfaceParityTest < ActionDispatch::IntegrationTest
  include SurfaceHelper

  DETAILED_EXCEPTIONS = "action_dispatch.show_detailed_exceptions".freeze

  # Everyone the test knows about. The fixtures give ana, dee, cy, eli and fay (see
  # test/fixtures/users.yml); setup adds the rest, so every visibility level exists on and off
  # the Every team. `team` is a verified @every.to address (fay's is not verified) and
  # `picks` says whether the person has a confirmed pick. Everyone here is onboarded.
  PEOPLE = {
    "ana" => { visibility: "link", team: true, picks: true },
    "dee" => { visibility: "team", team: true, picks: true },
    "cy" => { visibility: "only_me", team: true, picks: true },
    "eli" => { visibility: "link", team: false, picks: true },
    "fay" => { visibility: "link", team: false, picks: true },
    "olive" => { visibility: "team", team: false, picks: true },
    "otto" => { visibility: "only_me", team: false, picks: true },
    "vera" => { visibility: "link", team: true, picks: false },
    "newcomer" => { visibility: "only_me", team: false, picks: false }
  }.freeze

  # Viewer class => the handle who reads as that class (nil is a signed-out visitor).
  VIEWERS = {
    "a visitor" => nil,
    "a signed-in member outside Every" => "newcomer",
    "a verified Every member who shares with the team" => "dee",
    "an Every member whose picks are private" => "cy",
    "a member outside Every whose picks are private" => "otto"
  }.freeze

  SHOWS = %w[team others].freeze

  setup do
    @detailed_exceptions = Rails.application.env_config[DETAILED_EXCEPTIONS]
    Rails.application.env_config[DETAILED_EXCEPTIONS] = false

    add_person("newcomer", visibility: "only_me")
    add_person("vera", visibility: "link", team: true)
    olive = add_person("olive", visibility: "team")
    otto = add_person("otto", visibility: "only_me")
    add_pick(olive, :coding, 1, add_tool("Olive Tool"))
    add_pick(olive, :video, 1, :runway)
    add_pick(otto, :coding, 1, :cursor, model: :gpt_6)
    add_pick(otto, :coding, 2, add_tool("Otto Tool"))
    add_pick(otto, :knowledge_work, 1, :claude)
  end

  teardown { Rails.application.env_config[DETAILED_EXCEPTIONS] = @detailed_exceptions }

  # The pages and the tool agree

  VIEWERS.each do |label, viewer_handle|
    SHOWS.each do |show|
      test "AE1: Home, the Kind pages and get_team_rankings count the same people for #{label} reading #{show}" do
        viewer = viewer_handle && User.find_by!(handle: viewer_handle)
        sign_in_or_out(viewer)
        named = named(viewer_handle, show)
        counted = counted(viewer_handle, show)
        where = "#{label} / #{show}"

        home = read_home(show:)
        kinds = Category.order(:position).index_with { |category| read_kind(category, show) }

        assert_home_counts_the_population(home, named, counted, where)
        kinds.each { |category, kind| assert_kind_lists_what_the_population_ranked(kind, category, named, counted, where) }
        assert_nobody_hidden_is_named(viewer_handle, named, where, home.except(:current_user, :webmcp), kinds.values.map { |kind| kind.except(:current_user, :webmcp) })
        assert_tool_agrees_with_pages(viewer, show, home, kinds, counted, where) if viewer
      end
    end
  end

  test "the oracle really splits the sets: on the team a visitor counts three people and names one" do
    assert_equal %w[ana cy dee], counted(nil, "team")
    assert_equal %w[ana], named(nil, "team")
    assert_equal counted(nil, "others"), named(nil, "others")
  end

  # PERSON, search and the unknown handle

  VIEWERS.each do |label, viewer_handle|
    SHOWS.each do |show|
      test "AE2: PERSON and search offer exactly the people named, and any other handle is the unknown handle for #{label} reading #{show}" do
        sign_in_or_out(viewer_handle && User.find_by!(handle: viewer_handle))
        named = named(viewer_handle, show)
        where = "#{label} / #{show}"

        unknown = read_home(show:, person: "nobody-here")
        assert_nil unknown[:person]
        PEOPLE.each_key do |handle|
          home = read_home(show:, person: handle)

          if named.include?(handle)
            assert_equal handle, home.dig(:person, :person, :handle), "PERSON #{handle}, #{where}"
          else
            assert_equal unknown, home, "PERSON #{handle} is not offered, so it is the unknown handle, even when counted, #{where}"
          end
          found = partial_search(handle, show:)["people"].pluck("handle")
          assert_equal named.include?(handle) ? [ handle ] : [], found, "search for #{handle}, #{where}"
        end
      end
    end
  end

  VIEWERS.each do |label, viewer_handle|
    SHOWS.each do |show|
      test "search hits are the items the population ranked, with the Kind page's counts, for #{label} reading #{show}" do
        sign_in_or_out(viewer_handle && User.find_by!(handle: viewer_handle))
        counted = counted(viewer_handle, show)
        where = "#{label} / #{show}"

        { "cursor" => Tool, "olive tool" => Tool, "opus" => AiModel, "gpt" => AiModel }.each do |query, klass|
          hits = partial_search(query, show:)["items"]
          column = klass == Tool ? :tool_id : :ai_model_id
          held = klass.where(id: Entry.joins(:user).where(users: { handle: counted }).where.not(column => nil).select(column))
            .select { |item| item.name.downcase.include?(query) }.map(&:slug)

          assert_equal held.sort, hits.map { |hit| hit.dig("item", "slug") }.sort, "items for #{query.inspect}, #{where}"
          hits.each do |hit|
            hit.fetch("kinds").each do |entry|
              category = Category.find_by!(slug: entry.dig("category", "slug"))
              kind = read_kind(category, show)
              listing = kind[klass == Tool ? :tools : :models].find { |candidate| candidate.dig(:item, :slug) == hit.dig("item", "slug") }

              assert_equal listing[:count], entry["count"].symbolize_keys, "#{hit.dig("item", "slug")} in #{category.slug}, #{where}"
            end
          end
        end
      end
    end
  end

  # Not found is not found

  VIEWERS.each do |label, viewer_handle|
    test "AE2, R13: a profile or card #{label} may not open is the same not-found as a handle nobody claimed" do
      sign_in_or_out(viewer_handle && User.find_by!(handle: viewer_handle))
      unknown_page = not_found_answer("/nobody-here")
      unknown_card = card_answer("/nobody-here/og.png")
      assert_equal 404, unknown_card.first

      PEOPLE.each do |handle, person|
        name = User.find_by!(handle:).name
        where = "/#{handle} for #{label}"

        if openable?(viewer_handle, handle)
          get "/#{handle}"
          assert_response :success, where
          assert_inertia_component "profiles/show"
          assert_never_shared_cacheable where
        else
          assert_equal unknown_page, not_found_answer("/#{handle}"), where
          assert_not_includes response.body, name, where
        end

        # The card is drawn for a visitor whoever asks: served for a link profile with a
        # confirmed pick, and the unknown handle's 404 for everything else, the owner included.
        card = card_answer("/#{handle}/og.png")
        if person[:visibility] == "link" && person[:picks]
          assert_equal [ 200, "image/png" ], [ card.first, response.media_type ], "card of #{where}"
        else
          assert_equal unknown_card, card, "card of #{where}"
        end
      end
    end
  end

  private

  # The oracle: the visibility rule longhand, then who that leaves in the room.

  def team_member?(handle) = handle.present? && PEOPLE.fetch(handle)[:team]

  # A page is open to its owner, to anyone when it is shared with the link, and to Every team
  # members when it is shared with the team.
  def openable?(viewer_handle, handle)
    level = PEOPLE.fetch(handle)[:visibility]
    viewer_handle == handle || level == "link" || (level == "team" && team_member?(viewer_handle))
  end

  # Named: people the viewer may open who have a confirmed pick, in the SHOW class.
  def named(viewer_handle, show)
    PEOPLE.select { |handle, person| person[:picks] && openable?(viewer_handle, handle) && person[:team] == (show == "team") }.keys.sort
  end

  # Counted: on the team, every member with a confirmed pick whoever may open them; outside it, the named.
  def counted(viewer_handle, show)
    return named(viewer_handle, show) unless show == "team"

    (named(viewer_handle, show) + PEOPLE.select { |_handle, person| person[:picks] && person[:team] }.keys).uniq.sort
  end

  # Distinct people among the handles with a pick in the kind, straight from the rows.
  def people_with(handles, category:)
    Entry.joins(:user).where(users: { handle: handles }, category:).distinct.count(:user_id)
  end

  # item id => [[rank, handle], ...] for what the handles ranked in the kind.
  def ranked_by_item(handles, category, column)
    Entry.joins(:user).where(users: { handle: handles }, category:).where.not(column => nil)
      .pluck(column, :rank, "users.handle").group_by(&:first).transform_values { |rows| rows.map { |_id, rank, handle| [ rank, handle ] } }
  end

  # The status, body and caching headers of a share card request.
  def card_answer(path)
    get path
    [ response.status, response.body, response.headers.slice("Content-Type", "Cache-Control") ]
  end

  # Reading the pages

  def read_home(**params)
    get root_path, params: params
    assert_response :success
    assert_never_shared_cacheable "Home"
    page_props
  end

  def read_kind(category, show)
    get kind_path(category.slug), params: { show: }
    assert_response :success
    assert_never_shared_cacheable "Kind #{category.slug}"
    page_props
  end

  def assert_home_counts_the_population(home, named, counted, where)
    m = counted.size
    assert_equal named, home[:people].pluck(:handle).sort, "PERSON options, #{where}"
    assert_equal m, home[:hero][:people], "hero people, #{where}"
    assert_equal [ m ], all_counts(home.slice(:rows, :overall, :launches)).pluck(:of).uniq, "every count on Home is out of M, #{where}"
    assert_empty home[:rows].map { |row| row[:category][:slug] } - Category.pluck(:slug), "rows, #{where}"

    home[:rows].each do |row|
      category = Category.find_by!(slug: row[:category][:slug])
      assert_equal({ n: people_with(counted, category:), of: m }, row[:ranked], "K of M for #{category.slug}, #{where}")
    end
  end

  def assert_kind_lists_what_the_population_ranked(kind, category, named, counted, where)
    m = counted.size
    assert_equal({ n: people_with(counted, category:), of: m }, kind[:ranked], "K of M, #{category.slug}, #{where}")
    assert_equal [ m ], all_counts(kind.slice(:ranked, :tools, :models, :setups)).pluck(:of).uniq, "every count on the Kind page is out of M, #{where}"

    { tools: [ Tool, :tool_id ], models: [ AiModel, :ai_model_id ] }.each do |listing, (klass, column)|
      expected = ranked_by_item(counted, category, column)
      assert_equal klass.where(id: expected.keys).pluck(:slug).sort, kind[listing].map { |entry| entry.dig(:item, :slug) }.sort, "#{listing} of #{category.slug}, #{where}"

      kind[listing].each do |entry|
        rows = expected.fetch(klass.find_by!(slug: entry.dig(:item, :slug)).id)
        shown = rows.select { |_rank, handle| named.include?(handle) }
        names = by_rank(entry, :by_rank)

        assert_equal rows.map(&:last).uniq.size, entry.dig(:count, :n), "N of #{entry.dig(:item, :slug)} in #{category.slug}, #{where}"
        assert_equal (1..3).to_h { |rank| [ rank, shown.select { |r, _| r == rank }.map(&:last).sort ] }, names.transform_values(&:sort), "who is named for #{entry.dig(:item, :slug)} in #{category.slug}, #{where}"
        assert_equal (rows.map(&:last) - named).uniq.size, entry[:unnamed], "counted but unnamed, #{entry.dig(:item, :slug)} in #{category.slug}, #{where}"
        assert_equal entry.dig(:count, :n), names.values.sum(&:size) + entry[:unnamed], "the names and the unnamed add up to N, #{where}"
      end
    end
  end

  # No one the viewer may not open, or who is in the other SHOW class, is named by handle or
  # by name on any page or tool result, even when they are counted.
  def assert_nobody_hidden_is_named(viewer_handle, named, where, *outputs)
    text = outputs.to_json
    (PEOPLE.keys - named - [ viewer_handle ]).each do |handle|
      assert_not_includes text, %("handle":"#{handle}"), "#{handle} is named by handle, #{where}"
      assert_not_includes text, User.find_by!(handle:).name.to_json, "#{handle} is named, #{where}"
    end
  end

  def assert_tool_agrees_with_pages(viewer, show, home, kinds, counted, where)
    overview = tool_result(viewer, "get_team_rankings", audience: show)
    text = overview.to_json

    assert_equal [ show, counted.size ], overview.values_at(:audience, :people), "population, #{where}"
    assert_equal home[:hero][:people], overview[:people], "M on Home and in the tool, #{where}"
    assert_equal home[:rows].map { |row| row_summary(row, row.dig(:category, :slug)) }, overview[:kinds].map { |row| row_summary(row, row[:slug]) }, "the What we use rows, #{where}"
    assert_equal standings(home[:overall]), standings(overview[:overall]), "Overall top ten, #{where}"
    assert_equal home[:private_picks], overview.fetch(:includes_your_private_picks, false), "the private picks note, #{where}"

    kinds.each do |category, kind|
      detail = tool_result(viewer, "get_team_rankings", audience: show, category: category.slug)
      text += detail.to_json

      assert_equal kind[:ranked], detail[:ranked], "K of M, #{category.slug}, #{where}"
      assert_equal listings(kind[:tools], :by_rank), listings(detail[:tools], :ranked_by), "tools of #{category.slug}, #{where}"
      assert_equal listings(kind[:models], :by_rank), listings(detail[:models], :ranked_by), "models of #{category.slug}, #{where}"
      assert_equal setups(kind[:setups]), setups(detail[:setups]), "setups of #{category.slug}, #{where}"
      assert_equal kind[:takes].map { |take| [ take.dig(:model, :slug), take[:url] ] }, detail[:takes].map { |take| [ take.dig(:model, :slug), take[:vibe_check_url] ] }, "takes of #{category.slug}, #{where}"
      assert_equal [ kind[:last_update_at] ], [ detail[:last_update_at] ], "last update of #{category.slug}, #{where}"
    end

    absent = PEOPLE.keys - home[:people].pluck(:handle) - [ viewer.handle ]
    absent.each { |handle| assert_not_includes text, %("handle":"#{handle}"), "#{handle} is named by the tool, #{where}" }
  end

  # The same summaries from either surface, so equal means the same numbers and the same people.

  def row_summary(row, slug)
    [ slug, row[:ranked], leader(row[:top_tool]), leader(row[:top_model]), row[:last_update_at], row[:stale] ]
  end

  def leader(top)
    top && [ top.dig(:item, :slug), top[:count], top[:runner_up]&.then { |next_up| [ next_up.dig(:item, :slug), next_up[:count] ] } ]
  end

  def standings(overall)
    overall.transform_values { |list| list.map { |entry| [ entry.dig(:item, :slug), entry[:count] ] } }
  end

  def listings(entries, key)
    entries.map { |entry| [ entry.dig(:item, :slug), entry[:count], by_rank(entry, key), entry[key == :by_rank ? :unnamed : :unlisted] ] }
  end

  # { 1 => ["ana"], 2 => [...], 3 => [...] }, whatever the keys serialise as.
  def by_rank(entry, key)
    entry.fetch(key).to_h { |rank, people| [ rank.to_s.to_i, people.pluck(:handle) ] }
  end

  def setups(list)
    list.map { |setup| [ setup.dig(:tool, :slug), setup.dig(:model, :slug), setup[:context], setup[:effort], setup[:count] ] }
  end

  # Every { n:, of: } anywhere in a nested output.
  def all_counts(value)
    case value
    when Hash then (value.key?(:n) && value.key?(:of) ? [ value ] : []) + value.values.flat_map { |inner| all_counts(inner) }
    when Array then value.flat_map { |inner| all_counts(inner) }
    else []
    end
  end
end
