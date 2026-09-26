require "test_helper"
require Rails.root.join("db/migrate/20260818195630_allow_null_hero_on_geneva_drive_workflows")

class GenevaDriveMigrationTest < ActiveSupport::TestCase
  class MigrationRecord < ActiveRecord::Base
    self.abstract_class = true
  end

  test "nullable hero migration preserves SQLite step history and foreign keys" do
    MigrationRecord.establish_connection(adapter: "sqlite3", database: ":memory:")
    connection = MigrationRecord.connection
    build_pre_migration_schema(connection)
    seed_workflow_history(connection)

    migration = AllowNullHeroOnGenevaDriveWorkflows.new
    migration.define_singleton_method(:connection) { connection }
    migration.migrate(:up)

    assert_equal 1, connection.select_value("SELECT COUNT(*) FROM geneva_drive_workflows")
    assert_equal 1, connection.select_value("SELECT COUNT(*) FROM geneva_drive_step_executions")
    assert_empty connection.select_rows("PRAGMA foreign_key_check")
    assert connection.columns(:geneva_drive_workflows).find { |column| column.name == "hero_type" }.null
    assert connection.columns(:geneva_drive_workflows).find { |column| column.name == "hero_id" }.null
  ensure
    MigrationRecord.connection_pool.disconnect!
  end

  private

  def build_pre_migration_schema(connection)
    connection.create_table :geneva_drive_workflows do |table|
      table.string :type, null: false
      table.string :hero_type, null: false
      table.integer :hero_id, null: false
      table.string :state, null: false
      table.boolean :allow_multiple, null: false, default: false
      table.timestamps
    end
    connection.add_index :geneva_drive_workflows, [ :hero_type, :hero_id ]
    connection.add_index :geneva_drive_workflows,
      [ :type, :hero_type, :hero_id ],
      unique: true,
      where: "state NOT IN ('finished', 'canceled') AND allow_multiple = 0",
      name: "index_geneva_drive_workflows_unique_ongoing"

    connection.create_table :geneva_drive_step_executions do |table|
      table.integer :workflow_id, null: false
      table.string :step_name, null: false
      table.timestamps
    end
    connection.add_foreign_key :geneva_drive_step_executions,
      :geneva_drive_workflows,
      column: :workflow_id,
      on_delete: :cascade
  end

  def seed_workflow_history(connection)
    connection.execute <<~SQL.squish
      INSERT INTO geneva_drive_workflows
        (id, type, hero_type, hero_id, state, allow_multiple, created_at, updated_at)
      VALUES
        (1, 'TestWorkflow', 'User', 1, 'finished', 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    SQL
    connection.execute <<~SQL.squish
      INSERT INTO geneva_drive_step_executions
        (id, workflow_id, step_name, created_at, updated_at)
      VALUES
        (1, 1, 'complete', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    SQL
  end
end
