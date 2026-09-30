require "test_helper"

# The replay behind "What we used before". Every scenario is written through
# Toolbox::Update and travel_to (never by hand-written rows), so a test passes only
# when the writer and the reader agree. Dates are 2026 and days are UTC. A scenario
# reads "today" as August 10.
module HistoryReplayAssertions
  # A person's rows replay to exactly their picks, in every kind.
  def assert_replays(user)
    user.reload
    Category.find_each do |category|
      rows = user.entry_changes.where(category:, action: EntryChange::SLOT_ACTIONS).where.not(rank: nil).order(:created_at, :id)
      replayed = (NumberOneHistory.timeline(rows).last&.last || {}).transform_values { |change| pick_of(change) }
      current = user.entries.where(category:).to_h { |entry| [ entry.rank, pick_of(entry) ] }

      assert_equal current, replayed, "#{user.handle}'s #{category.name} rows should replay to their picks"
    end
    assert_replays_to_entries(user)
  end

  private

  def pick_of(record) = [ record.tool_id, record.ai_model_id, record.context, record.effort ]
end

# Fixture people are removed so a population is exactly the one a test builds; the
# fixture universe is checked in NumberOneHistoryFixturesTest below.
#
# On the team every onboarded member counts every day they have picks, whatever they
# share and whoever is looking; a private member is never named, and an era names no
# one. Visibility periods clip history only outside the team (SHOW others), so the
# period scenarios are written with `outsider`s read by a team viewer under "others".
class NumberOneHistoryTest < ActiveSupport::TestCase
  include HistoryReplayAssertions

  TODAY = Time.utc(2026, 8, 10, 12)

  setup do
    User.delete_all
    @coding = categories(:coding)
    @cursor = tools(:cursor)
    @claude_code = tools(:claude_code)
    @zed = add_tool("Zed")
    @windsurf = add_tool("Windsurf")
  end

  def on(month, day, hour = 9) = travel_to(Time.utc(2026, month, day, hour))

  # A verified @every.to address, so the person is on the team.
  def member(handle, visibility: "team") = add_person(handle, visibility:, team: true)

  # A non-team address, so the person is in SHOW others and their periods clip them.
  def outsider(handle, visibility: "team") = add_person(handle, visibility:, team: false)

  def person(handle, team:, visibility: "team") = team ? member(handle, visibility:) : outsider(handle, visibility:)

  def rank(user, position, tool, model: nil, category: "coding", **choices)
    Toolbox::Update.call(
      user:, source: "web",
      operations: [ { op: "set_pick", category:, rank: position, tool: tool.slug, model: model&.slug, **choices } ]
    )
  end

  def write(user, *operations, source: "web", **options)
    Toolbox::Update.call(user:, source:, operations:, **options)
  end

  def eras(viewer, show: nil, today: TODAY)
    travel_to today
    NumberOneHistory.new(viewer:, show:).eras(@coding)
  end

  def era(from, to, tool, model = nil)
    { from:, to:, tool: tool.to_prop, model: model&.to_prop }
  end

  # The last era is today's number one, so it is the Kind table's leader.
  def assert_current_era_matches_kind_table(eras, viewer, show: nil)
    assert_nil eras.last[:to], "the last era should run to today"
    kind = TeamRankings.new(viewer:, show:).kind(@coding)

    assert_equal [ kind[:tools].first[:item], kind[:models].first&.dig(:item) ], [ eras.last[:tool], eras.last[:model] ]
  end

  def watcher = @watcher ||= member("watcher", visibility: "only_me")

  # Cursor leads on people alone: two of them rank it, and every other tool has one.
  def three_teammates(team: true)
    on 1, 5, 10
    ana, bob, cyd = %w[ana bob cyd].map { |handle| person(handle, team:) }
    rank ana, 1, @zed
    rank ana, 2, @cursor
    rank bob, 1, @windsurf
    rank bob, 2, @cursor
    rank cyd, 1, @claude_code
    [ ana, bob, cyd ]
  end

  # Dan ranks Claude Code (2 people, 2 first picks) past Cursor (2 people, none first).
  def dan_shares_from_march_to_may(again_in_july:, team: true)
    three_teammates(team:)
    on 3, 2
    dan = person("dan", team:)
    rank dan, 1, @claude_code
    on 5, 4
    dan.update!(visibility: "only_me")
    if again_in_july
      on 7, 6
      dan.update!(visibility: "team")
    end
    dan
  end

  # AE4, the shape of the history

  test "AE4: outside the team, a fourth person counts for March to May and from July on, not while they were Only me" do
    dan_shares_from_march_to_may(again_in_july: true, team: false)

    result = eras(watcher, show: "others")

    assert_equal(
      [
        era("2026-01-05", "2026-03-01", @cursor),
        era("2026-03-02", "2026-05-04", @claude_code),
        era("2026-05-05", "2026-07-05", @cursor),
        era("2026-07-06", nil, @claude_code)
      ],
      result
    )
    assert_current_era_matches_kind_table(result, watcher, show: "others")
  end

  test "AE4: outside the team, a person who is Only me today counts for no day at all, in anyone else's history" do
    dan_shares_from_march_to_may(again_in_july: false, team: false)

    assert_equal [ era("2026-01-05", nil, @cursor) ], eras(watcher, show: "others")
    assert_equal [], eras(nil, show: "others"), "team-only sharers are nobody's business to a visitor"
  end

  [ true, false ].each do |again_in_july|
    test "on the team, a member counts every day from their first pick, for every viewer, whatever they share (again in July: #{again_in_july})" do
      dan = dan_shares_from_march_to_may(again_in_july:)
      expected = [ era("2026-01-05", "2026-03-01", @cursor), era("2026-03-02", nil, @claude_code) ]

      [ watcher, nil, dan ].each do |viewer|
        result = eras(viewer)
        assert_equal expected, result, "for #{viewer&.handle || "a visitor"}"
        assert_current_era_matches_kind_table(result, viewer)
      end
    end
  end

  test "on the team, a member who is Only me today moves the history but is named nowhere" do
    dan_shares_from_march_to_may(again_in_july: false)
    assert_equal "only_me", User.find_by!(handle: "dan").visibility

    { watcher => 1, nil => 2 }.each do |viewer, unnamed|
      kind = TeamRankings.new(viewer:).kind(@coding)
      claude_code = kind[:tools].find { |entry| entry[:item][:slug] == @claude_code.slug }
      assert_equal 2, claude_code[:count][:n], "cyd and dan"
      assert_equal unnamed, claude_code[:unnamed], "dan, and for a visitor team-only cyd too, counted anonymously"
      assert_not_includes kind.to_json, "\"dan\""
      assert_not_includes eras(viewer).to_json, "dan"
    end
  end

  test "a viewer's own history is included in full, even while they are Only me" do
    dan = dan_shares_from_march_to_may(again_in_july: false)

    result = eras(dan)

    assert_equal [ era("2026-01-05", "2026-03-01", @cursor), era("2026-03-02", nil, @claude_code) ], result
    assert_current_era_matches_kind_table(result, dan)
  end

  test "AE4: outside the team, an anonymous or non-team viewer never sees a team-only period" do
    on 1, 5, 10
    people = %w[pia quinn rex].map { |handle| outsider(handle, visibility: "team") }
    people.each { |person| rank person, 1, @cursor }
    on 2, 10
    people.each { |person| rank person, 1, @claude_code }
    on 4, 1
    people.each { |person| person.update!(visibility: "link") }
    nina = outsider("nina", visibility: "only_me")

    assert_equal [ era("2026-01-05", "2026-02-09", @cursor), era("2026-02-10", nil, @claude_code) ], eras(watcher, show: "others")
    assert_equal [ era("2026-04-01", nil, @claude_code) ], eras(nil, show: "others"), "they went public on April 1; the team-only months do not exist for a visitor"
    assert_equal eras(nil, show: "others"), eras(nina, show: "others")
    assert_current_era_matches_kind_table(eras(nil, show: "others"), nil, show: "others")
  end

  test "on the team, a visitor and a non-team viewer read the same history as a member, team-only months included" do
    on 1, 5, 10
    people = %w[pia quinn rex].map { |handle| member(handle, visibility: "team") }
    people.each { |person| rank person, 1, @cursor }
    on 2, 10
    people.each { |person| rank person, 1, @claude_code }
    nina = outsider("nina", visibility: "only_me")

    full = [ era("2026-01-05", "2026-02-09", @cursor), era("2026-02-10", nil, @claude_code) ]
    [ watcher, nil, nina ].each { |viewer| assert_equal full, eras(viewer) }
    assert_current_era_matches_kind_table(eras(nil), nil)
    assert_empty Audience.new(viewer: nil).people, "a visitor counts them but may name none of them"
  end

  # Same-day edits after narrowing

  {
    "an every-team period" => [ "team", :team_viewer ],
    "an anyone-with-the-link period" => [ "link", :visitor ]
  }.each do |name, (level, who)|
    test "outside the team, an edit made after narrowing on the same day never counts, for #{name}" do
      on 1, 5, 10
      ana, bob, cyd = %w[ana bob cyd].map { |handle| outsider(handle, visibility: level) }
      rank ana, 1, @windsurf
      rank ana, 2, @claude_code
      rank bob, 1, @zed
      rank bob, 2, @claude_code
      rank cyd, 1, @cursor
      pat = outsider("pat", visibility: level)
      rank pat, 1, @cursor
      on 3, 10, 9
      pat.update!(visibility: "only_me")
      on 3, 10, 15
      rank pat, 1, @zed
      on 6, 1, 9
      pat.update!(visibility: level)

      viewer = who == :team_viewer ? watcher : nil

      assert_equal(
        [
          era("2026-01-05", "2026-03-10", @cursor),
          era("2026-03-11", "2026-05-31", @claude_code),
          era("2026-06-01", nil, @zed)
        ],
        eras(viewer, show: "others"),
        "March 10 is Pat's last shared day and is sampled at 09:00, before the Zed edit"
      )
    end
  end

  test "on the team, narrowing changes nothing: an edit counts from the day it is made" do
    on 1, 5, 10
    ana, bob, cyd = %w[ana bob cyd].map { |handle| member(handle) }
    rank ana, 1, @windsurf
    rank ana, 2, @claude_code
    rank bob, 1, @zed
    rank bob, 2, @claude_code
    rank cyd, 1, @cursor
    pat = member("pat")
    rank pat, 1, @cursor
    on 3, 10, 9
    pat.update!(visibility: "only_me")
    on 3, 10, 15
    rank pat, 1, @zed

    [ watcher, nil ].each do |viewer|
      assert_equal [ era("2026-01-05", "2026-03-09", @cursor), era("2026-03-10", nil, @zed) ], eras(viewer),
        "the Zed edit counts at the end of March 10 though Pat was Only me by then"
    end
  end

  # Pat's swap flips the leader from Cursor to Claude Code (2 people each, Claude Code with more 1st picks).
  {
    Time.utc(2026, 3, 10, 23, 59, 59) => [ "2026-03-09", "2026-03-10" ],
    Time.utc(2026, 3, 11, 0, 0, 0) => [ "2026-03-10", "2026-03-11" ]
  }.each do |swapped_at, (last_cursor_day, first_claude_code_day)|
    test "a swap made at #{swapped_at.strftime("%H:%M:%S on %B %-d")} first counts on #{first_claude_code_day}" do
      on 1, 5, 10
      ana, bob, cyd = %w[ana bob cyd].map { |handle| member(handle) }
      rank ana, 1, @cursor
      rank bob, 1, @claude_code
      rank cyd, 1, @zed
      pat = member("pat")
      rank pat, 1, @cursor
      rank pat, 2, @claude_code
      travel_to swapped_at
      write pat, { op: "move_pick", category: "coding", rank: 1, direction: "down" }

      swap = EntryChange.where(action: "moved")
      assert_equal 2, swap.count
      assert_equal 1, swap.distinct.count(:created_at), "both rows of the swap carry one timestamp"

      assert_equal [ era("2026-01-05", last_cursor_day, @cursor), era(first_claude_code_day, nil, @claude_code) ], eras(watcher)
    end
  end

  test "a swap is applied whole: neither of the two picks is lost" do
    on 1, 5, 10
    ana, bob, cyd = %w[ana bob cyd].map { |handle| member(handle) }
    rank ana, 1, @cursor
    rank cyd, 1, @cursor
    rank bob, 1, @claude_code
    pat = member("pat")
    rank pat, 1, @cursor
    rank pat, 2, @claude_code
    on 3, 10
    write pat, { op: "move_pick", category: "coding", rank: 1, direction: "down" }

    assert_equal [ era("2026-01-05", nil, @cursor) ], eras(watcher), "Cursor keeps three people on Pat's 2nd pick; losing it would hand the tie to Claude Code"
  end

  # Who makes a day count

  test "fewer than three people is no history, so one or two sharers never form an era" do
    on 1, 5
    rank member("ana"), 1, @cursor
    rank member("bob"), 1, @cursor

    assert_equal [], eras(watcher)
  end

  test "history starts on the day a third person is sharing" do
    on 1, 5
    rank member("ana"), 1, @cursor
    rank member("bob"), 1, @cursor
    on 3, 2
    rank member("cyd"), 1, @claude_code

    assert_equal [ era("2026-03-02", nil, @cursor) ], eras(watcher)
  end

  test "a person who shares but has not ranked the kind is not one of the three" do
    on 1, 5
    rank member("ana"), 1, @cursor
    rank member("bob"), 1, @cursor
    rank member("cyd"), 1, tools(:runway), category: "video"

    assert_equal [], eras(watcher)
  end

  test "outside the team, a person is counted from the day they share, though they ranked earlier" do
    three_teammates(team: false)
    on 2, 1
    lee = outsider("lee", visibility: "only_me")
    rank lee, 1, @claude_code
    rank lee, 2, @zed
    on 3, 1
    lee.update!(visibility: "team")

    for_others = eras(watcher, show: "others")
    assert_equal [ era("2026-01-05", "2026-02-28", @cursor), era("2026-03-01", nil, @claude_code) ], for_others,
      "Lee's Claude Code (a 1st pick) and Zed make Claude Code the most used, but only from March 1"
    assert_current_era_matches_kind_table(for_others, watcher, show: "others")
  end

  test "on the team, a member is counted from the day they rank, whatever they shared then" do
    three_teammates
    on 2, 1
    lee = member("lee", visibility: "only_me")
    rank lee, 1, @claude_code
    rank lee, 2, @zed
    on 3, 1
    lee.update!(visibility: "team")

    [ watcher, nil, lee ].each do |viewer|
      result = eras(viewer)
      assert_equal [ era("2026-01-05", "2026-01-31", @cursor), era("2026-02-01", nil, @claude_code) ], result, "the same history as Lee's own"
      assert_current_era_matches_kind_table(result, viewer)
    end
  end

  # Ordering

  test "equal people are ordered by first picks, then by name, as on the Kind page" do
    on 1, 5
    ana, bob, cyd = %w[ana bob cyd].map { |handle| member(handle) }
    rank ana, 1, @zed
    rank bob, 1, @cursor
    rank cyd, 1, @claude_code
    by_name = eras(watcher)
    assert_equal [ era("2026-01-05", nil, @claude_code) ], by_name
    assert_current_era_matches_kind_table(by_name, watcher)

    on 2, 1
    rank ana, 1, @cursor
    rank bob, 1, @zed
    rank bob, 2, @cursor
    rank cyd, 1, @zed
    by_firsts = eras(watcher)

    assert_equal [ era("2026-01-05", "2026-01-31", @claude_code), era("2026-02-01", nil, @zed) ], by_firsts,
      "Cursor and Zed both have people, and Zed has more 1st picks even though Cursor's name sorts first"
    assert_current_era_matches_kind_table(by_firsts, watcher)
  end

  test "the model leader is reported with the tool leader and an era changes when either does" do
    opus, gpt = ai_models(:opus_5_5), ai_models(:gpt_6)
    on 1, 5, 10
    ana, bob, cyd = %w[ana bob cyd].map { |handle| member(handle) }
    rank ana, 1, @cursor, model: opus
    rank bob, 1, @claude_code, model: opus
    rank cyd, 1, @zed, model: gpt
    on 2, 10
    rank ana, 1, @cursor, model: gpt
    rank bob, 1, @claude_code, model: gpt

    result = eras(watcher)

    assert_equal [ era("2026-01-05", "2026-02-09", @claude_code, opus), era("2026-02-10", nil, @claude_code, gpt) ], result
    assert_current_era_matches_kind_table(result, watcher)
  end

  test "a model waiting for review is not a leader until it is approved" do
    on 1, 5, 10
    people = %w[ana bob cyd].map { |handle| member(handle) }
    people.each { |person| write person, { op: "set_pick", category: "coding", rank: 1, tool: @cursor.slug, model: "Mystery 9" } }
    mystery = AiModel.find_by!(name: "Mystery 9")

    assert mystery.pending?
    waiting = eras(watcher)
    assert_equal [ era("2026-01-05", nil, @cursor) ], waiting
    assert_current_era_matches_kind_table(waiting, watcher)

    mystery.update!(status: "approved")

    approved = eras(watcher)
    assert_equal [ era("2026-01-05", nil, @cursor, mystery) ], approved
    assert_current_era_matches_kind_table(approved, watcher)
  end

  test "a tool waiting for review is not a leader until it is approved" do
    on 1, 5, 10
    people = %w[ana bob cyd].map { |handle| member(handle) }
    people.each do |person|
      write person, { op: "set_pick", category: "coding", rank: 1, tool: "Mystery IDE" }
      rank person, 2, @cursor
    end
    # Each person's "Mystery IDE" is their own until an admin folds the duplicates.
    mystery, *duplicates = Tool.where(name: "Mystery IDE").order(:id)
    duplicates.each { |duplicate| Catalog::Merge.call(source: duplicate, target: mystery) }

    assert mystery.pending?
    waiting = eras(watcher)
    assert_equal [ era("2026-01-05", nil, @cursor) ], waiting
    assert_current_era_matches_kind_table(waiting, watcher)

    mystery.update!(status: "approved")

    approved = eras(watcher)
    assert_equal [ era("2026-01-05", nil, mystery) ], approved
    assert_current_era_matches_kind_table(approved, watcher)
  end

  # What the rows may say

  test "suggested and dismissed rows never change state; a confirmed suggestion does" do
    on 1, 5, 10
    ana, bob, cyd = %w[ana bob cyd].map { |handle| member(handle) }
    rank ana, 1, @claude_code
    rank bob, 1, @claude_code
    rank cyd, 1, @cursor
    on 1, 8
    write ana, { op: "suggest", category: "coding", tool: @cursor.slug, rank: 1 }, source: "mcp", client_name: "Claude"
    on 1, 9
    write ana, { op: "dismiss", suggestion_id: ana.pick_suggestions.first.id }
    on 1, 12
    write bob, { op: "suggest", category: "coding", tool: @cursor.slug, rank: 1 }, source: "mcp", client_name: "Claude"
    on 1, 13
    write bob, { op: "confirm", suggestion_id: bob.pick_suggestions.last.id, rank: 1, expected: { tool: @claude_code.slug, model: nil } }

    assert_equal %w[suggested dismissed], ana.entry_changes.where(action: %w[suggested dismissed]).order(:id).pluck(:action)
    assert_equal [ era("2026-01-05", "2026-01-12", @claude_code), era("2026-01-13", nil, @cursor) ], eras(watcher)
    [ ana, bob, cyd ].each { |person| assert_replays(person) }
  end

  test "legacy rows without a rank are ignored" do
    ana, bob, cyd = three_teammates
    on 1, 6
    [ ana, bob, cyd ].each do |person|
      EntryChange.create!(user: person, category: @coding, tool: @zed, action: "added", source: "web")
      EntryChange.create!(user: person, category: @coding, tool: @zed, action: "made_primary", source: "web")
      EntryChange.create!(user: person, category: @coding, tool: @zed, action: "set", source: "web", details: { batch: "unranked" })
    end

    assert_equal [ era("2026-01-05", nil, @cursor) ], eras(watcher)
  end

  test "migration baseline rows carry a person's picks into the days they share" do
    three_teammates(team: false)
    on 1, 20
    lee = outsider("lee", visibility: "only_me")
    Entry.create!(user: lee, category: @coding, tool: @claude_code, rank: 1)
    Entry.create!(user: lee, category: @coding, tool: @zed, rank: 2)
    lee.entries.each do |entry|
      EntryChange.create!(
        user: lee, category: @coding, tool: entry.tool, action: "baseline", source: "system", rank: entry.rank,
        details: { batch: "baseline-#{lee.id}" }
      )
    end
    on 2, 1
    lee.update!(visibility: "team")

    assert_replays(lee)
    assert_equal [ era("2026-01-05", "2026-01-31", @cursor), era("2026-02-01", nil, @claude_code) ], eras(watcher, show: "others"),
      "the baseline is Lee's state when they start sharing; without it Cursor would lead throughout"
  end

  test "AE10: outside the team, a person who was never visible cannot move anyone else's history" do
    three_teammates(team: false)
    before = eras(watcher, show: "others")
    on 2, 1
    hidden = outsider("hid", visibility: "only_me")
    rank hidden, 1, @claude_code
    rank hidden, 2, @zed
    on 3, 1
    rank hidden, 1, @windsurf
    write hidden, { op: "suggest", category: "coding", tool: @cursor.slug }, source: "mcp", client_name: "Claude"

    assert_equal before, eras(watcher, show: "others")
    assert_equal [ era("2026-01-05", nil, @cursor) ], before, "guard: the leader really is Cursor, which Claude Code and Zed picks would have unseated"
  end

  test "AE10: on the team, a member who was never visible moves everyone's history, and only by their picks" do
    three_teammates
    before = eras(watcher)
    assert_equal [ era("2026-01-05", nil, @cursor) ], before
    on 2, 1
    hidden = member("hid", visibility: "only_me")
    rank hidden, 1, @claude_code
    rank hidden, 2, @zed
    on 3, 1
    rank hidden, 1, @windsurf
    write hidden, { op: "suggest", category: "coding", tool: @cursor.slug }, source: "mcp", client_name: "Claude"

    moved = [
      era("2026-01-05", "2026-01-31", @cursor),
      era("2026-02-01", "2026-02-28", @claude_code),
      era("2026-03-01", nil, @windsurf)
    ]
    [ watcher, nil ].each { |viewer| assert_equal moved, eras(viewer), "Claude Code, then Windsurf, each with two 1st picks; the suggestion moves nothing" }
    assert_equal [], eras(watcher, show: "others"), "a member never reaches the others' history"
    assert_not_includes Audience.new(viewer: watcher).people.pluck(:handle), "hid"
  end

  test "a deleted person no longer influences any era" do
    dan = dan_shares_from_march_to_may(again_in_july: true)
    assert_equal 2, eras(watcher).size

    dan.destroy!

    assert_equal [ era("2026-01-05", nil, @cursor) ], eras(watcher)
  end

  test "every SHOW class has its own history, and a team viewer reads the team periods of the others" do
    on 1, 5, 10
    people = %w[ann ben cat].map { |handle| add_person(handle, visibility: "team") }
    people.each { |person| rank person, 1, @cursor }

    assert_equal [], eras(watcher), "the team has nobody ranking yet"
    assert_equal [ era("2026-01-05", nil, @cursor) ], eras(watcher, show: "others")
    assert_equal [], eras(nil, show: "others"), "their pages are for the team; a visitor reads nothing"
    assert_current_era_matches_kind_table(eras(watcher, show: "others"), watcher, show: "others")
  end

  # The shape, and the work it does

  test "an era is exactly from, to, tool and model with ISO dates; nobody using a model gives nil" do
    three_teammates

    assert_equal [ { from: "2026-01-05", to: nil, tool: @cursor.to_prop, model: nil } ], eras(watcher)
    assert_equal %i[from to tool model], eras(watcher).first.keys
  end

  test "the replay is a fixed number of queries, however long the history" do
    dan_shares_from_march_to_may(again_in_july: true, team: false)
    %w[max mia moe].each { |handle| rank member(handle), 1, @cursor }
    watcher

    counts = ->(today, show) do
      travel_to today
      statements = []
      counter = ->(*, payload) { statements << payload[:sql] unless payload[:name] == "SCHEMA" }
      ActiveRecord::Base.uncached do
        ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { assert_not_empty NumberOneHistory.new(viewer: watcher, show:).eras(@coding) }
      end
      statements.filter_map { |sql| sql[/FROM "(\w+)"/, 1] }.tally
    end

    { "others" => 1, "team" => 0 }.each do |show, period_queries|
      short = counts.(TODAY, show)
      long = counts.(Time.utc(2029, 8, 10), show)

      assert_equal short, long, "no query per day (#{show})"
      assert_equal 1, short["entry_changes"]
      assert_equal period_queries, short.fetch("visibility_periods", 0), "only the others are clipped by periods"
    end
  end

  test "the replay equals the picks after a swap, a compaction, a confirmed suggestion and a removal" do
    on 1, 5
    ana = member("ana")
    rank ana, 1, @cursor, model: ai_models(:opus_5_5), context: "1m", effort: "high"
    rank ana, 2, @claude_code
    rank ana, 3, @zed
    assert_replays(ana)

    on 1, 6
    write ana, { op: "move_pick", category: "coding", rank: 1, direction: "down" }
    assert_replays(ana)

    on 1, 7
    write ana, { op: "remove_pick", category: "coding", rank: 1 }
    assert_replays(ana)
    assert_equal 2, ana.entries.count

    on 1, 8
    write ana, { op: "suggest", category: "coding", tool: @windsurf.slug, rank: 3 }, source: "webmcp", client_name: "WebMCP"
    assert_replays(ana)
    write ana, { op: "confirm", suggestion_id: ana.pick_suggestions.last.id }
    assert_replays(ana)
    assert_equal 3, ana.entries.count

    on 1, 9
    rank ana, 2, @zed, model: nil, effort: "low"
    write ana, { op: "remove_pick", category: "coding", rank: 3 }
    assert_replays(ana)
  end
end

# The fixture universe (test/fixtures). Its change rows have hash ids rather than ids in
# time order, so the replay must not lean on the ids alone.
class NumberOneHistoryFixturesTest < ActiveSupport::TestCase
  include HistoryReplayAssertions

  test "the replay of every fixture person equals their entries" do
    assert_operator User.count, :>, 5

    User.find_each { |user| assert_replays(user) }
  end

  test "the fixture team is three coders, one of them private, and every viewer reads the same history" do
    coding = categories(:coding)
    day = ->(days_ago) { days_ago.days.ago.beginning_of_hour.utc.to_date.iso8601 }
    expected = [
      # From dee's first pick: Cursor for ana (2nd), cy and dee; Opus 5 and GPT-6 tie on one 1st pick each, and Claude Opus 5 sorts first.
      { from: day.(55), to: day.(41), tool: tools(:cursor).to_prop, model: ai_models(:opus_5).to_prop },
      # From ana's and dee's swaps: Opus 5.5 for both of them.
      { from: day.(40), to: nil, tool: tools(:cursor).to_prop, model: ai_models(:opus_5_5).to_prop }
    ]

    [ nil, users(:one), users(:every_dee), users(:every_ana), users(:every_cy), users(:outside_eli), users(:every_fay) ].each do |viewer|
      assert_equal expected, NumberOneHistory.new(viewer:, show: "team").eras(coding), "team history for #{viewer&.handle || "a visitor"}"
    end
  end

  test "the fixture others are two people, so there is no history to show" do
    coding = categories(:coding)

    [ nil, users(:every_dee), users(:every_ana), users(:outside_eli) ].each do |viewer|
      assert_equal [], NumberOneHistory.new(viewer:, show: "others").eras(coding)
    end
  end
end
