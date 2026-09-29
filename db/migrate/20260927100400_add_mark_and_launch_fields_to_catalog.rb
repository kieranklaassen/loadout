# A catalog item can carry a real product mark, and a model a Vibe Check link.
# tools and ai_models are parents of entries, so a rebuild (which is what Rails'
# remove_column does on SQLite) would delete every pick: down uses native DROP COLUMN.
class AddMarkAndLaunchFieldsToCatalog < ActiveRecord::Migration[8.1]
  def up
    add_column :tools, :mark, :string
    add_column :ai_models, :mark, :string
    add_column :ai_models, :vibe_check_url, :string
  end

  def down
    execute "ALTER TABLE ai_models DROP COLUMN vibe_check_url"
    execute "ALTER TABLE ai_models DROP COLUMN mark"
    execute "ALTER TABLE tools DROP COLUMN mark"
  end
end
