require "test_helper"
require "tmpdir"

# Runs the repo's real migrations against a scratch SQLite file: up to the last v1
# version, a populated v1 database, then the redesign migrations. SQLite rebuilds a
# table for remove_column, add_check_constraint, change_column_null and friends, and
# a rebuilt users table cascade-deletes entries and entry_changes (docs/modules/
# geneva_drive.md), so the guard here is that nothing but the documented drops changes.
class EveryLoadoutRedesignMigrationTest < ActiveSupport::TestCase
  class ScratchRecord < ActiveRecord::Base
    self.abstract_class = true
  end

  # A pinned outer transaction on the scratch pool would turn every migration's
  # DDL transaction into a savepoint; migrations run for real here.
  self.use_transactional_tests = false

  LAST_V1_VERSION = "20260926230200"
  REDESIGN_VERSIONS = %w[20260927100000 20260927100100 20260927100200 20260927100300 20260927100400].freeze
  ENTRIES_REBUILD_VERSION = "20260927100200"
  CATEGORY_SLUGS = %w[coding knowledge-work writing research classification image video animation text-to-speech speech-to-text music other].freeze

  setup do
    @dir = Dir.mktmpdir("redesign-migration")
    @started_at = Time.current.change(usec: 0)
    ScratchRecord.establish_connection(adapter: "sqlite3", database: File.join(@dir, "scratch.sqlite3"))
    @connection = ScratchRecord.lease_connection
  end

  teardown do
    ScratchRecord.remove_connection
    FileUtils.remove_entry(@dir)
  end

  test "the redesign migrations keep every user, session, grant and tool and drop only what the plan says" do
    migrate_through(LAST_V1_VERSION)
    populate_v1_database
    before = counts(%w[users sessions oauth_clients oauth_grants tools ai_models])

    migrate_through(REDESIGN_VERSIONS.last)

    assert_equal before, counts(%w[users sessions oauth_clients oauth_grants tools ai_models])
    assert_empty @connection.select_rows("PRAGMA foreign_key_check")
    assert_equal [ [ "ok" ] ], @connection.select_rows("PRAGMA integrity_check")
    assert_equal CATEGORY_SLUGS - [ "other" ], @connection.select_values("SELECT slug FROM categories ORDER BY id")
    assert_equal 1, @connection.select_value("SELECT created_by_id FROM tools WHERE id = 7"), "a table rebuild would null the creator"
  end

  test "a user with four picks in a kind and a go-to on the second keeps three, the go-to first" do
    migrate_through(LAST_V1_VERSION)
    populate_v1_database
    migrate_through(REDESIGN_VERSIONS.last)

    assert_equal [ [ 12, 1 ], [ 11, 2 ], [ 13, 3 ] ], @connection.select_rows("SELECT id, rank FROM entries WHERE user_id = 1 AND category_id = 1 ORDER BY rank")
    assert_equal [ [ 15, 1 ] ], @connection.select_rows("SELECT id, rank FROM entries WHERE user_id = 1 AND category_id = 2")
    assert_equal [ 9 ], @connection.select_values("SELECT COUNT(*) FROM entries")
    assert_equal %w[id user_id category_id tool_id ai_model_id rank context effort created_at updated_at], @connection.columns("entries").map(&:name)
    assert_equal [ [ nil, nil ] ], @connection.select_rows("SELECT DISTINCT context, effort FROM entries")
    assert_ranks_contiguous
  end

  test "duplicate tools in a kind keep the go-to, then the pick with a model, then the earliest" do
    migrate_through(LAST_V1_VERSION)
    populate_v1_database
    migrate_through(REDESIGN_VERSIONS.last)

    assert_equal [ [ 21, 1 ], [ 23, 2 ] ], @connection.select_rows("SELECT id, rank FROM entries WHERE user_id = 2 AND category_id = 1 ORDER BY rank"), "equal picks: the earliest wins"
    assert_equal [ [ 25, 1 ] ], @connection.select_rows("SELECT id, rank FROM entries WHERE user_id = 2 AND category_id = 3"), "the pick with a model beats the earlier one without"
    assert_equal [ [ 26, 1 ] ], @connection.select_rows("SELECT id, rank FROM entries WHERE user_id = 2 AND category_id = 4"), "the go-to beats the one with a model"
  end

  test "dropped picks, notes and the other kind are archived with counts, privately" do
    migrate_through(LAST_V1_VERSION)
    populate_v1_database
    migrate_through(REDESIGN_VERSIONS.last)

    path = File.join(@dir, "migration_archive", "#{ENTRIES_REBUILD_VERSION}_rework_entries_for_ranked_picks.json")
    assert_equal 0o600, File.stat(path).mode & 0o777
    archive = JSON.parse(File.read(path))

    assert_equal({ "other_entries" => 1, "duplicate_tool_entries" => 3, "entries_beyond_three" => 1, "notes" => 2, "other_entry_changes" => 2 }, archive["counts"])
    assert_equal [ 16 ], archive["other_entries"].map { |row| row["id"] }
    assert_equal [ 22, 24, 27 ], archive["duplicate_tool_entries"].map { |row| row["id"] }.sort
    assert_equal [ 14 ], archive["entries_beyond_three"].map { |row| row["id"] }
    assert_equal({ 11 => "keeps me fast", 22 => "second try" }, archive["notes"].to_h { |row| [ row["id"], row["note"] ] })
    assert_equal [ 106, 107 ], archive["other_entry_changes"].map { |row| row["id"] }.sort
  end

  test "legacy change rows survive except the other kind's, and every person with picks gets a baseline" do
    migrate_through(LAST_V1_VERSION)
    populate_v1_database
    migrate_through(REDESIGN_VERSIONS.last)

    assert_equal [ 101, 102, 103, 104, 105, 108, 109, 110 ], @connection.select_values("SELECT id FROM entry_changes WHERE action <> 'baseline' ORDER BY id")
    assert_equal [ nil ], @connection.select_values("SELECT DISTINCT rank FROM entry_changes WHERE action <> 'baseline'")

    baselines = @connection.select_all("SELECT * FROM entry_changes WHERE action = 'baseline'").to_a
    assert_equal 9, baselines.size
    assert_equal [ "system" ], baselines.map { |row| row["source"] }.uniq
    assert_equal [ 1, 2, 3 ], baselines.map { |row| row["user_id"] }.uniq.sort, "people without picks get no baseline"
    assert_equal({ 1 => 2, 2 => 1, 3 => 3 }, baselines.select { |row| row["user_id"] == 1 && row["category_id"] == 1 }.to_h { |row| [ row["rank"], row["tool_id"] ] })
    assert_equal [ "baseline-1" ], baselines.select { |row| row["user_id"] == 1 }.map { |row| JSON.parse(row["details"])["batch"] }.uniq
    assert_operator baselines.map { |row| Time.find_zone!("UTC").parse(row["created_at"]) }.min, :>=, @started_at
  end

  test "a person who was public gets one link period and a baseline at the same instant" do
    migrate_through(LAST_V1_VERSION)
    populate_v1_database
    migrate_through(REDESIGN_VERSIONS.last)

    assert_equal [ [ 1, "link" ], [ 5, "link" ] ], @connection.select_rows("SELECT id, visibility FROM users WHERE visibility <> 'only_me' ORDER BY id")
    periods = @connection.select_all("SELECT user_id, level, starts_at, ends_at FROM visibility_periods ORDER BY user_id").to_a
    assert_equal [ [ 1, "link", nil ], [ 5, "link", nil ] ], periods.map { |row| row.values_at("user_id", "level", "ends_at") }
    assert_operator Time.find_zone!("UTC").parse(periods.first["starts_at"]), :>=, @started_at

    baseline_times = @connection.select_values("SELECT DISTINCT created_at FROM entry_changes WHERE action = 'baseline' AND user_id = 1")
    assert_equal [ periods.first["starts_at"] ], baseline_times
    assert_equal [ false ], @connection.select_values("SELECT DISTINCT email_verified FROM users").map { |value| value == 1 }
  end

  test "not public, not onboarded or without a handle stays only me with no period" do
    migrate_through(LAST_V1_VERSION)
    populate_v1_database
    migrate_through(REDESIGN_VERSIONS.last)

    assert_equal %w[only_me], @connection.select_values("SELECT visibility FROM users WHERE id IN (2, 3, 4)").uniq
    assert_equal 0, @connection.select_value("SELECT COUNT(*) FROM visibility_periods WHERE user_id IN (2, 3, 4)")
  end

  test "a legacy only-me person's replay equals their entries, so sharing later starts from the right state" do
    migrate_through(LAST_V1_VERSION)
    populate_v1_database
    migrate_through(REDESIGN_VERSIONS.last)

    [ 1, 2, 3 ].each do |user_id|
      changes = @connection.select_all("SELECT * FROM entry_changes WHERE user_id = #{user_id}").to_a
      entries = @connection.select_all("SELECT * FROM entries WHERE user_id = #{user_id}").to_a
      expected = entries.to_h { |row| [ [ row["category_id"], row["rank"] ], [ row["tool_id"], row["ai_model_id"], row["context"], row["effort"] ] ] }

      assert_equal expected, replay_slots(changes), "user #{user_id}"
    end
  end

  test "the other kind is removed from catalog hints and nothing else in them changes" do
    migrate_through(LAST_V1_VERSION)
    populate_v1_database
    migrate_through(REDESIGN_VERSIONS.last)

    assert_equal [ %w[coding], [], %w[coding knowledge-work] ], [ 7, 8, 1 ].map { |id| JSON.parse(@connection.select_value("SELECT category_slugs FROM tools WHERE id = #{id}")) }
    assert_equal [ %w[coding] ], [ JSON.parse(@connection.select_value("SELECT category_slugs FROM ai_models WHERE id = 2")) ]
  end

  test "the database enforces one tool and one rank per kind and cascades to the new tables" do
    migrate_through(LAST_V1_VERSION)
    populate_v1_database
    migrate_through(REDESIGN_VERSIONS.last)

    assert_raises(ActiveRecord::RecordNotUnique) { insert_entry(id: 90, user_id: 1, category_id: 1, tool_id: 5, rank: 1) }
    assert_raises(ActiveRecord::RecordNotUnique) { insert_entry(id: 91, user_id: 1, category_id: 1, tool_id: 1, rank: 4) }
    assert_raises(ActiveRecord::NotNullViolation) { insert_entry(id: 92, user_id: 1, category_id: 6, tool_id: 1, rank: nil) }

    insert(:visibility_periods, user_id: 2, level: "team", starts_at: @started_at, ends_at: nil)
    insert(:pick_suggestions, user_id: 2, category_id: 1, tool_id: 1, status: "open", created_at: @started_at, updated_at: @started_at)
    assert_raises(ActiveRecord::RecordNotUnique) { insert(:visibility_periods, user_id: 2, level: "link", starts_at: @started_at, ends_at: nil) }

    @connection.execute("DELETE FROM sessions WHERE user_id = 2")
    @connection.execute("DELETE FROM users WHERE id = 2")
    assert_equal [ 0, 0, 0, 0 ], %w[entries entry_changes visibility_periods pick_suggestions].map { |table| @connection.select_value("SELECT COUNT(*) FROM #{table} WHERE user_id = 2") }
    assert_empty @connection.select_rows("PRAGMA foreign_key_check")
  end

  test "the migrated schema equals a schema-loaded database" do
    migrate_through(LAST_V1_VERSION)
    populate_v1_database
    migrate_through(REDESIGN_VERSIONS.last)

    schema_loaded = structure(ActiveRecord::Base.lease_connection)
    migrated = structure(@connection)

    assert_equal schema_loaded.keys, migrated.keys
    schema_loaded.each { |table, expected| assert_equal expected, migrated[table], "#{table} differs from the schema-loaded table" }
  end

  test "a fresh database migrates with nothing to archive" do
    migrate_through(REDESIGN_VERSIONS.last)

    assert_empty @connection.select_rows("PRAGMA foreign_key_check")
    assert_not File.exist?(File.join(@dir, "migration_archive"))
  end

  test "the additive migrations roll back without touching users, entries or their children" do
    migrate_through(LAST_V1_VERSION)
    populate_v1_database
    migrate_through(REDESIGN_VERSIONS.last)
    before = counts(%w[users sessions oauth_grants tools entries entry_changes])

    REDESIGN_VERSIONS.values_at(4, 3).each { |version| migrate_down(version) }
    assert_equal before, counts(%w[users sessions oauth_grants tools entries entry_changes])
    assert_not @connection.table_exists?(:pick_suggestions)
    assert_equal %w[id slug name maker hue monogram status category_slugs created_by_id position created_at updated_at admin_edited_at], @connection.columns("tools").map(&:name)

    assert_raises(ActiveRecord::IrreversibleMigration) { migrate_down(REDESIGN_VERSIONS[2]) }
  end

  test "the visibility and slot-state migrations roll back without rebuilding users or their history" do
    migrate_through(LAST_V1_VERSION)
    populate_v1_database
    v1_change_columns = @connection.columns("entry_changes").map(&:name)
    migrate_through(REDESIGN_VERSIONS[1])
    before = counts(%w[users sessions oauth_grants tools entries entry_changes])

    migrate_down(REDESIGN_VERSIONS[1])
    migrate_down(REDESIGN_VERSIONS[0])

    assert_equal before, counts(%w[users sessions oauth_grants tools entries entry_changes])
    assert_not @connection.table_exists?(:visibility_periods)
    assert_not_includes @connection.columns("users").map(&:name), "visibility"
    assert_equal v1_change_columns, @connection.columns("entry_changes").map(&:name)
  end

  private

  def migration_files
    Dir[Rails.root.join("db/migrate/*.rb")].sort_by { |file| File.basename(file) }
  end

  def version_of(file) = File.basename(file)[/\A\d+/]

  def migration_class(file)
    require file
    File.basename(file, ".rb").sub(/\A\d+_/, "").camelize.constantize
  end

  # Runs every not-yet-run migration up to and including version, the way the
  # migrator does: each in its own DDL transaction on the scratch connection.
  def migrate_through(version)
    ActiveRecord::Migration.suppress_messages do
      migration_files.each do |file|
        next if version_of(file) > version || (@migrated ||= []).include?(version_of(file))

        @connection.transaction { migration_class(file).new.exec_migration(@connection, :up) }
        @migrated << version_of(file)
      end
    end
  end

  def migrate_down(version)
    file = migration_files.find { |candidate| version_of(candidate) == version }
    ActiveRecord::Migration.suppress_messages do
      @connection.transaction { migration_class(file).new.exec_migration(@connection, :down) }
    end
  end

  def counts(tables)
    tables.to_h { |table| [ table, @connection.select_value("SELECT COUNT(*) FROM #{table}") ] }
  end

  def assert_ranks_contiguous
    ranks = @connection.select_rows("SELECT user_id, category_id, rank FROM entries ORDER BY user_id, category_id, rank").group_by { |user_id, category_id, _| [ user_id, category_id ] }
    ranks.each { |kind, rows| assert_equal (1..rows.size).to_a, rows.map(&:last), "ranks for user and kind #{kind.inspect}" }
  end

  # Columns, indexes, foreign keys and check constraints per table, in no particular
  # order: two databases compare on structure and not on the order older table
  # rebuilds happened to leave columns and constraints in.
  def structure(connection)
    ordered = ->(rows) { rows.sort_by { |row| row.map(&:to_s) } }
    (connection.tables - %w[schema_migrations ar_internal_metadata]).sort.to_h do |table|
      [ table, {
        columns: ordered.(connection.columns(table).map { |column| [ column.name, column.sql_type, column.null, column.default, column.default_function ] }),
        indexes: ordered.(connection.indexes(table).map { |index| [ index.name, index.columns, index.unique, index.where, index.orders ] }),
        foreign_keys: ordered.(connection.foreign_keys(table).map { |key| [ key.to_table, key.column, key.primary_key, key.on_delete, key.on_update ] }),
        check_constraints: ordered.(connection.check_constraints(table).map { |check| [ check.name, check.expression ] })
      } ]
    end
  end

  def insert(table, **row)
    columns = row.keys.map { |column| @connection.quote_column_name(column) }.join(", ")
    values = row.values.map { |value| @connection.quote(value) }.join(", ")
    @connection.execute("INSERT INTO #{@connection.quote_table_name(table)} (#{columns}) VALUES (#{values})")
  end

  def insert_entry(id:, user_id:, category_id:, tool_id:, rank:)
    insert(:entries, id:, user_id:, category_id:, tool_id:, ai_model_id: nil, rank:, context: nil, effort: nil, created_at: @started_at, updated_at: @started_at)
  end

  # Six people, the way the v1 schema and code leave them (see the plan's AE8).
  def populate_v1_database
    at = ->(day) { Time.utc(2026, 9, day, 12) }

    [
      [ 1, "ana@every.to", "ana", 1, at.(1) ], [ 2, "bo@every.to", "bo", 0, at.(1) ], [ 3, "cy@every.to", "cy", 1, nil ],
      [ 4, "dee@every.to", nil, 1, at.(1) ], [ 5, "eli@every.to", "eli", 1, at.(1) ]
    ].each do |id, email, handle, public, onboarded_at|
      insert(:users, id:, email_address: email, handle:, public:, admin: 0, onboarded_at:, created_at: at.(1), updated_at: at.(1))
    end
    [ [ 1, 1 ], [ 2, 2 ] ].each { |id, user_id| insert(:sessions, id:, user_id:, created_at: at.(1), updated_at: at.(1)) }
    insert(:oauth_clients, id: 1, client_id: "client-1", client_name: "Claude", redirect_uris: [ "https://claude.ai/cb" ].to_json, created_at: at.(1), updated_at: at.(1))
    insert(:oauth_grants, id: 1, user_id: 1, oauth_client_id: 1, resource: "https://example.test/mcp", scope: "loadout", access_digest: "a", access_expires_at: at.(2),
      refresh_digest: "r", refresh_expires_at: at.(30), created_at: at.(1), updated_at: at.(1))

    CATEGORY_SLUGS.each.with_index(1) { |slug, id| insert(:categories, id:, slug:, name: slug.humanize, position: id, created_at: at.(1), updated_at: at.(1)) }
    [
      [ 1, "cursor", %w[coding knowledge-work], nil ], [ 2, "claude-code", %w[coding], nil ], [ 3, "codex", %w[coding], nil ], [ 4, "zed", %w[coding], nil ],
      [ 5, "claude", %w[knowledge-work], nil ], [ 6, "perplexity", %w[research], nil ], [ 7, "member-tool", %w[coding other], 1 ], [ 8, "other-only", %w[other], 2 ]
    ].each do |id, slug, slugs, created_by_id|
      insert(:tools, id:, slug:, name: slug.humanize, monogram: "Xx", hue: 10, status: "approved", category_slugs: slugs.to_json, created_by_id:, position: id, created_at: at.(1), updated_at: at.(1))
    end
    [ [ 1, "claude-opus-5-5", %w[coding] ], [ 2, "gpt-6-astra", %w[coding other] ] ].each do |id, slug, slugs|
      insert(:ai_models, id:, slug:, name: slug.humanize, monogram: "Xx", hue: 10, status: "approved", category_slugs: slugs.to_json, position: id, created_at: at.(1), updated_at: at.(1))
    end

    # id, user, category, tool, model, note, go-to, created day
    [
      [ 11, 1, 1, 1, 1, "keeps me fast", 0, 1 ], [ 12, 1, 1, 2, 1, nil, 1, 2 ], [ 13, 1, 1, 3, nil, nil, 0, 3 ], [ 14, 1, 1, 4, nil, nil, 0, 4 ],
      [ 15, 1, 2, 5, 1, nil, 1, 1 ], [ 16, 1, 12, 5, nil, nil, 0, 1 ],
      [ 21, 2, 1, 1, 1, nil, 0, 1 ], [ 22, 2, 1, 1, 2, "second try", 0, 2 ], [ 23, 2, 1, 2, nil, nil, 0, 3 ],
      [ 24, 2, 3, 5, nil, nil, 0, 5 ], [ 25, 2, 3, 5, 1, nil, 0, 6 ],
      [ 26, 2, 4, 6, nil, nil, 1, 7 ], [ 27, 2, 4, 6, 2, nil, 0, 8 ],
      [ 31, 3, 1, 3, nil, nil, 1, 1 ]
    ].each do |id, user_id, category_id, tool_id, ai_model_id, note, primary, day|
      insert(:entries, id:, user_id:, category_id:, tool_id:, ai_model_id:, note:, primary:, created_at: at.(day), updated_at: at.(day))
    end

    # id, user, category, tool, action
    [
      [ 101, 1, 1, 1, "added" ], [ 102, 1, 1, 2, "added" ], [ 103, 1, 1, 2, "made_primary" ], [ 104, 1, 1, 4, "added" ], [ 105, 1, 2, 5, "added" ],
      [ 106, 1, 12, 5, "added" ], [ 107, 1, 12, 1, "updated" ], [ 108, 2, 1, 1, "added" ], [ 109, 2, 1, 1, "removed" ], [ 110, 3, 1, 3, "added" ]
    ].each do |id, user_id, category_id, tool_id, action|
      insert(:entry_changes, id:, user_id:, category_id:, tool_id:, action:, source: "web", details: { batch: "b#{id}" }.to_json, created_at: at.(id - 100))
    end
  end
end
