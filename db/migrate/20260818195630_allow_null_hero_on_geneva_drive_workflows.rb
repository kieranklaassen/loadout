# frozen_string_literal: true

class AllowNullHeroOnGenevaDriveWorkflows < ActiveRecord::Migration[7.2]
  def up
    return unless column_exists?(:geneva_drive_workflows, :hero_type)

    if connection.adapter_name.downcase.include?("sqlite")
      allow_null_hero_sqlite
    else
      change_column_null :geneva_drive_workflows, :hero_type, true
      change_column_null :geneva_drive_workflows, :hero_id, true
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
      "Cannot re-add NOT NULL on hero columns without rejecting hero-less workflows"
  end

  private

  def allow_null_hero_sqlite
    transaction do
      remove_foreign_key :geneva_drive_step_executions,
        :geneva_drive_workflows,
        column: :workflow_id

      old_columns = connection.columns(:geneva_drive_workflows)
      old_pk = connection.primary_key(:geneva_drive_workflows)
      pk_column = old_columns.find { |column| column.name == old_pk }
      data_columns = old_columns.reject { |column| column.name == old_pk }

      create_table :geneva_drive_workflows_new, id: pk_column.type do |table|
        data_columns.each do |column|
          nullable = %w[hero_type hero_id].include?(column.name) || column.null
          options = { null: nullable }
          default = column.default_function || column.default
          options[:default] = default unless default.nil?
          table.column column.name, column.type, **options
        end
      end

      column_names = old_columns.map(&:name).join(", ")
      execute <<~SQL.squish
        INSERT INTO geneva_drive_workflows_new (#{column_names})
        SELECT #{column_names} FROM geneva_drive_workflows
      SQL

      drop_table :geneva_drive_workflows
      rename_table :geneva_drive_workflows_new, :geneva_drive_workflows

      add_index :geneva_drive_workflows, :type
      add_index :geneva_drive_workflows, :state
      add_index :geneva_drive_workflows, [ :hero_type, :hero_id ]
      execute <<~SQL
        CREATE UNIQUE INDEX index_geneva_drive_workflows_unique_ongoing
        ON geneva_drive_workflows (type, hero_type, hero_id)
        WHERE state NOT IN ('finished', 'canceled') AND allow_multiple = 0;
      SQL

      add_foreign_key :geneva_drive_step_executions,
        :geneva_drive_workflows,
        column: :workflow_id,
        on_delete: :cascade
    end
  end
end
