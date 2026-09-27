require "test_helper"
require Rails.root.join("db/migrate/20260927110000_remove_public_map_flag")

class RemovePublicMapFlagMigrationTest < ActiveSupport::TestCase
  class MigrationRecord < ActiveRecord::Base
    self.abstract_class = true
  end

  setup do
    MigrationRecord.establish_connection(adapter: "sqlite3", database: ":memory:")
    @connection = MigrationRecord.connection
  end

  teardown { MigrationRecord.connection_pool.disconnect! }

  test "deletes the public_map flag and its gates and leaves every other flag alone" do
    create_flipper_tables
    %w[public_map focus_mode].each do |key|
      @connection.execute("INSERT INTO flipper_features (key, created_at, updated_at) VALUES ('#{key}', '2026-09-27', '2026-09-27')")
      @connection.execute("INSERT INTO flipper_gates (feature_key, key, value, created_at, updated_at) VALUES ('#{key}', 'boolean', 'true', '2026-09-27', '2026-09-27')")
    end

    run_migration

    assert_equal [ "focus_mode" ], @connection.select_values("SELECT key FROM flipper_features")
    assert_equal [ "focus_mode" ], @connection.select_values("SELECT feature_key FROM flipper_gates")
  end

  test "does nothing on a database that never had the flipper tables" do
    assert_nothing_raised { run_migration }
  end

  private

  def run_migration
    connection = @connection
    migration = RemovePublicMapFlag.new
    migration.define_singleton_method(:connection) { connection }
    ActiveRecord::Migration.suppress_messages { migration.migrate(:up) }
  end

  def create_flipper_tables
    @connection.create_table(:flipper_features) { |t| t.string :key, null: false; t.timestamps }
    @connection.create_table(:flipper_gates) { |t| t.string :feature_key, null: false; t.string :key, null: false; t.text :value; t.timestamps }
  end
end
