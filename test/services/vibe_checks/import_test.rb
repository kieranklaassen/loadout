require "test_helper"

class VibeChecks::ImportTest < ActiveSupport::TestCase
  NOW = Time.utc(2026, 9, 30, 12)
  FIRST = "https://every.to/vibe-check/first"
  SECOND = "https://every.to/vibe-check/second"

  setup do
    @dee = users(:every_dee)
    @coding = categories(:coding)
    @dee.entry_changes.delete_all
    @dee.entries.delete_all
    @dee.reload
  end

  test "writes each snapshot as a dated batch and empties the slots when the history runs out" do
    import snapshot(on: "2026-05-01", url: FIRST, picks: [ { tool: "claude-code", model: "claude-opus-5" }, { tool: "cursor" } ]),
      snapshot(on: "2026-06-01", url: SECOND, picks: [ { tool: "cursor", model: "claude-opus-5-5" } ])

    rows = @dee.entry_changes.order(:created_at, :id).map { |change| [ change.created_at.to_date.iso8601, change.action, change.rank, change.tool.slug, change.ai_model&.slug ] }
    assert_equal [
      [ "2026-05-01", "set", 1, "claude-code", "claude-opus-5" ],
      [ "2026-05-01", "set", 2, "cursor", nil ],
      [ "2026-06-01", "set", 1, "cursor", "claude-opus-5-5" ],
      [ "2026-06-01", "removed", 2, "cursor", nil ],
      [ "2026-08-30", "removed", 1, "cursor", "claude-opus-5-5" ]
    ], rows
    assert_equal [ "vibe_check" ], @dee.entry_changes.distinct.pluck(:source)
    assert_equal [ FIRST, SECOND ], @dee.entry_changes.order(:created_at).map { |change| change.details["vibe_check"] }.uniq
    assert_replays_to_entries @dee
  end

  test "a gap longer than STALE_AFTER closes the older snapshot before the next one" do
    import snapshot(on: "2026-01-01", url: FIRST, picks: [ { tool: "cursor" } ]),
      snapshot(on: "2026-06-01", url: SECOND, picks: [ { tool: "cursor" } ])

    timeline = NumberOneHistory.timeline(@dee.entry_changes.order(:created_at, :id).to_a)
    assert_equal [ Date.new(2026, 1, 1), Date.new(2026, 4, 1), Date.new(2026, 6, 1), Date.new(2026, 8, 30) ], timeline.map { |time, _| time.to_date }
    assert_equal [ 1, 0, 1, 0 ], timeline.map { |_, slots| slots.size }
  end

  test "stops at the member's own first change in the kind, so history still replays to their picks" do
    travel_to Time.utc(2026, 7, 1, 9) do
      Toolbox::Update.call(user: @dee, source: "web", operations: [ { op: "set_pick", category: "coding", rank: 1, tool: "claude-code" } ])
    end

    import snapshot(on: "2026-05-01", url: FIRST, picks: [ { tool: "cursor" }, { tool: "claude" } ]),
      snapshot(on: "2026-07-15", url: SECOND, picks: [ { tool: "claude" } ])

    imported = @dee.entry_changes.where(source: "vibe_check").order(:created_at, :id)
    assert_equal [ [ "set", 1 ], [ "set", 2 ], [ "removed", 1 ], [ "removed", 2 ] ], imported.map { |change| [ change.action, change.rank ] }
    assert_equal Time.utc(2026, 7, 1, 8, 59, 59), imported.last.created_at
    assert_replays_to_entries @dee
  end

  test "is safe to run again and leaves every other row alone" do
    travel_to Time.utc(2026, 9, 1) do
      Toolbox::Update.call(user: @dee, source: "web", operations: [ { op: "set_pick", category: "video", rank: 1, tool: "runway" } ])
    end
    data = [ snapshot(on: "2026-05-01", url: FIRST, picks: [ { tool: "cursor" } ]) ]

    first = import(*data)
    ids = @dee.entry_changes.where.not(source: "vibe_check").pluck(:id)
    second = import(*data)

    assert_equal first, second
    assert_equal ids, @dee.entry_changes.where.not(source: "vibe_check").pluck(:id)
    assert_equal 2, @dee.entry_changes.where(source: "vibe_check").count
  end

  test "finds a member by name when the email differs, and skips anyone outside the verified team" do
    people = {
      "someone-else@every.to" => { "name" => @dee.name, "snapshots" => [ snapshot(on: "2026-05-01", url: FIRST, picks: [ { tool: "cursor" } ]) ] },
      users(:every_fay).email_address => { "snapshots" => [ snapshot(on: "2026-05-01", url: FIRST, picks: [ { tool: "cursor" } ]) ] },
      "nobody@every.to" => { "snapshots" => [ snapshot(on: "2026-05-01", url: FIRST, picks: [ { tool: "cursor" } ]) ] }
    }

    written = run_import(people)

    assert_equal({ @dee.email_address => 2 }, written)
    assert_not users(:every_fay).entry_changes.exists?(source: "vibe_check")
  end

  test "closing rows stay out of the member's story; the picks read as dated changes" do
    import snapshot(on: "2026-05-01", url: FIRST, picks: [ { tool: "cursor" } ])

    sentences = Toolbox::Presenter.new(@dee).recent_changes.map { |change| change[:sentence] }
    assert_equal [ "Set Cursor as first pick for coding" ], sentences
  end

  test "three members' Vibe Checks give the kind a number one before anyone ranked, retired models included" do
    Catalog::Sync.call
    retired = AiModel.find_by!(slug: "claude-opus-4-6")
    people = [ @dee, users(:every_ana), users(:every_cy) ]
    people.each { |person| person.entry_changes.where(category: @coding).delete_all }
    Entry.where(user: people, category: @coding).delete_all
    # History counts the people in the room today, and that is whoever has a pick somewhere.
    travel_to(Time.utc(2026, 9, 1)) { people.each { |person| Toolbox::Update.call(user: person, source: "web", operations: [ { op: "set_pick", category: "video", rank: 1, tool: "runway" } ]) } }
    run_import(people.to_h { |person| [ person.email_address, { "snapshots" => [ snapshot(on: "2026-02-05", url: FIRST, picks: [ { tool: "claude-code", model: retired.slug } ]) ] } ] })

    era = travel_to(NOW) { NumberOneHistory.new(viewer: @dee).eras(@coding) }.first
    assert_equal [ "2026-02-05", "claude-code", retired.slug ], [ era[:from], era[:tool][:slug], era[:model][:slug] ]
  end

  test "names the snapshot that points at something the catalog does not have" do
    error = assert_raises(VibeChecks::Import::Error) do
      import snapshot(on: "2026-05-01", url: FIRST, picks: [ { tool: "no-such-tool" } ])
    end
    assert_match "no-such-tool", error.message
  end

  test "the shipped file names only catalog items and kinds" do
    Catalog::Sync.call

    assert_nothing_raised { VibeChecks::Import.new(now: NOW).send(:snapshots_by_person) }
  end

  private

  def snapshot(on:, url:, picks:, kind: "coding")
    { "date" => Date.parse(on), "url" => url, "kind" => kind, "picks" => picks.map { |pick| pick.transform_keys(&:to_s) } }
  end

  def import(*snapshots)
    run_import(@dee.email_address => { "snapshots" => snapshots })
  end

  def run_import(people)
    file = Tempfile.new([ "vibe_checks", ".yml" ])
    file.write({ "people" => people }.to_yaml)
    file.close
    VibeChecks::Import.call(path: file.path, now: NOW)
  ensure
    file&.unlink
  end
end
