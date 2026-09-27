# A person now holds up to three ranked picks per kind of work, each tool at most
# once. The old shape (any number of picks, a go-to flag, a note) does not fit, so
# entries is rebuilt once, in SQL: nothing has a foreign key to entries, so the
# copy, drop and rename cannot cascade into other tables.
#
# What is dropped, and only this, is archived first:
#   - picks in the "other" kind, with its change rows and its category
#   - a repeated tool in a kind (kept: the go-to, then the pick with a model, then the earliest)
#   - picks past the third (the go-to, then the oldest, keep their places)
#   - notes (the column goes away)
# The archive is a JSON file next to the database (storage/migration_archive/, mode
# 0600); it holds private notes, so delete it once the deploy is verified.
#
# Every person who has picks also gets one `baseline` change row per pick, so the
# change history replays to today's state whatever they choose to share. It is
# stamped with the instant their link period began, if they have one.
class ReworkEntriesForRankedPicks < ActiveRecord::Migration[8.1]
  MAX_RANK = 3
  ENTRY_COLUMNS = %w[id user_id category_id tool_id ai_model_id note primary created_at updated_at].freeze
  KEPT_TABLES = %w[users sessions oauth_clients oauth_authorization_codes oauth_grants tools ai_models].freeze

  def up
    other_id = connection.select_value("SELECT id FROM categories WHERE slug = 'other'") || -1
    before = table_counts
    archive = dropped_rows(other_id)

    drop_other_kind(other_id)
    rebuild_entries(other_id)
    baselines = write_baselines

    verify!(before, archive, baselines)
    write_archive(archive)
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Picks beyond three, repeated tools, notes and the other kind were dropped; restore the database backup instead."
  end

  private

  # Survivors in two steps: one row per tool per kind, then ranks per kind.
  def ranked_entries(table, other_id)
    <<~SQL
      WITH deduped AS (
        SELECT *, row_number() OVER (
          PARTITION BY user_id, category_id, tool_id
          ORDER BY "primary" DESC, ai_model_id IS NULL, created_at, id
        ) AS tool_position
        FROM #{table} WHERE category_id <> #{other_id}
      ), ranked AS (
        SELECT *, row_number() OVER (
          PARTITION BY user_id, category_id
          ORDER BY "primary" DESC, created_at, id
        ) AS new_rank
        FROM deduped WHERE tool_position = 1
      )
    SQL
  end

  def dropped_rows(other_id)
    columns = ENTRY_COLUMNS.map { |column| connection.quote_column_name(column) }.join(", ")
    {
      "other_entries" => connection.select_all("SELECT #{columns} FROM entries WHERE category_id = #{other_id} ORDER BY id").to_a,
      "duplicate_tool_entries" => connection.select_all("#{ranked_entries("entries", other_id)} SELECT #{columns} FROM deduped WHERE tool_position > 1 ORDER BY id").to_a,
      "entries_beyond_three" => connection.select_all("#{ranked_entries("entries", other_id)} SELECT #{columns} FROM ranked WHERE new_rank > #{MAX_RANK} ORDER BY id").to_a,
      "notes" => connection.select_all("SELECT id, user_id, category_id, tool_id, note FROM entries WHERE trim(note) <> '' ORDER BY id").to_a,
      "other_entry_changes" => connection.select_all("SELECT * FROM entry_changes WHERE category_id = #{other_id} ORDER BY id").to_a
    }
  end

  def drop_other_kind(other_id)
    execute "DELETE FROM entry_changes WHERE category_id = #{other_id}"
    execute "DELETE FROM entries WHERE category_id = #{other_id}"
    execute "DELETE FROM categories WHERE id = #{other_id}"

    %w[tools ai_models].each do |table|
      execute <<~SQL
        UPDATE #{table}
        SET category_slugs = (SELECT json_group_array(value) FROM json_each(#{table}.category_slugs) WHERE value <> 'other')
        WHERE EXISTS (SELECT 1 FROM json_each(#{table}.category_slugs) WHERE value = 'other')
      SQL
    end
  end

  def rebuild_entries(other_id)
    execute "ALTER TABLE entries RENAME TO entries_legacy"

    create_table :entries do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :category, null: false, foreign_key: true, index: false
      t.references :tool, null: false, foreign_key: true, index: false
      t.references :ai_model, foreign_key: true, index: false
      t.integer :rank, null: false
      t.string :context
      t.string :effort
      t.timestamps
    end

    execute <<~SQL
      #{ranked_entries("entries_legacy", other_id)}
      INSERT INTO entries (id, user_id, category_id, tool_id, ai_model_id, rank, created_at, updated_at)
      SELECT id, user_id, category_id, tool_id, ai_model_id, new_rank, created_at, updated_at FROM ranked WHERE new_rank <= #{MAX_RANK}
    SQL
    drop_table :entries_legacy

    # Both unique keys are on NOT NULL columns, so SQLite's NULLs-are-distinct rule
    # cannot let a duplicate through (the trap the old model-less index existed for).
    add_index :entries, %i[user_id category_id rank], unique: true
    add_index :entries, %i[user_id category_id tool_id], unique: true
    add_index :entries, :category_id
    add_index :entries, :tool_id
    add_index :entries, :ai_model_id
  end

  def write_baselines
    execute <<~SQL
      INSERT INTO entry_changes (user_id, category_id, tool_id, ai_model_id, action, source, details, created_at, rank)
      SELECT e.user_id, e.category_id, e.tool_id, e.ai_model_id, 'baseline', 'system',
        json_object('batch', 'baseline-' || e.user_id),
        COALESCE((SELECT MIN(p.starts_at) FROM visibility_periods p WHERE p.user_id = e.user_id), #{connection.quote(Time.current)}),
        e.rank
      FROM entries e
    SQL
    connection.select_value("SELECT COUNT(*) FROM entry_changes WHERE action = 'baseline'")
  end

  def table_counts
    (KEPT_TABLES + %w[categories entries entry_changes]).index_with { |table| connection.select_value("SELECT COUNT(*) FROM #{table}") }
  end

  # Raises inside the migration's transaction, so a mismatch rolls everything back.
  def verify!(before, archive, baselines)
    after = table_counts
    KEPT_TABLES.each { |table| ensure_that(before[table] == after[table], "#{table} went from #{before[table]} to #{after[table]} rows") }
    dropped = archive.values_at("other_entries", "duplicate_tool_entries", "entries_beyond_three").sum(&:size)
    ensure_that(after["entries"] == before["entries"] - dropped, "entries went from #{before["entries"]} to #{after["entries"]} rows, expected #{dropped} fewer")
    expected_changes = before["entry_changes"] - archive["other_entry_changes"].size + baselines
    ensure_that(after["entry_changes"] == expected_changes, "entry_changes has #{after["entry_changes"]} rows, expected #{expected_changes}")
    ensure_that(connection.select_rows("PRAGMA foreign_key_check").empty?, "foreign_key_check found orphaned rows")
    ensure_that(connection.select_value("PRAGMA integrity_check") == "ok", "integrity_check failed")
  end

  def ensure_that(condition, message)
    raise "Entries migration check failed: #{message}" unless condition
  end

  def write_archive(archive)
    counts = archive.transform_values(&:size)
    return if counts.values.sum.zero?

    directory = File.join(File.dirname(File.expand_path(connection.pool.db_config.database, Rails.root)), "migration_archive")
    FileUtils.mkdir_p(directory, mode: 0o700)
    path = File.join(directory, "#{File.basename(__FILE__, ".rb")}.json")
    File.open(path, File::WRONLY | File::CREAT | File::TRUNC, 0o600) do |file|
      file.write(JSON.pretty_generate({ "migration" => File.basename(__FILE__, ".rb"), "archived_at" => Time.current.iso8601, "counts" => counts }.merge(archive)))
    end
    File.chmod(0o600, path)
    say "Archived #{counts.to_json} to #{path}"
  end
end
