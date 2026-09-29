# Who may open a person's page is a plain column on users plus a table of the
# spans they shared. users is never rebuilt: on SQLite remove_column,
# add_check_constraint, change_column_null and a NOT NULL column without a default
# all copy, drop and rename the table, and the drop cascade-deletes entries and
# entry_changes and nulls tools.created_by_id (docs/modules/geneva_drive.md).
# add_column with a default is a plain ALTER, and so is the native DROP COLUMN below.
class AddVisibilityAndPeriods < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :visibility, :string, null: false, default: "only_me"
    add_column :users, :email_verified, :boolean, null: false, default: false

    create_table :visibility_periods do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.string :level, null: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at
      t.check_constraint "level IN ('team', 'link')", name: "visibility_periods_level_check"
    end
    add_index :visibility_periods, %i[user_id starts_at]
    add_index :visibility_periods, :user_id, unique: true, where: "ends_at IS NULL", name: "index_visibility_periods_one_open_per_user"

    # A public, onboarded profile was readable by anyone: it becomes "Anyone with the
    # link", shared since now. Everyone else stays "Only me" and has no period.
    execute "UPDATE users SET visibility = 'link' WHERE public = 1 AND handle IS NOT NULL AND onboarded_at IS NOT NULL"
    execute "INSERT INTO visibility_periods (user_id, level, starts_at) SELECT id, 'link', #{connection.quote(Time.current)} FROM users WHERE visibility = 'link'"
  end

  def down
    drop_table :visibility_periods
    execute "ALTER TABLE users DROP COLUMN email_verified"
    execute "ALTER TABLE users DROP COLUMN visibility"
  end
end
