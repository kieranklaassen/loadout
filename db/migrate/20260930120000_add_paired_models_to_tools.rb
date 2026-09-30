# A tool lists the models it runs (model families or model slugs, see config/catalog.yml),
# so the Rank editor offers Veo 3.1 for Veo instead of every LLM.
# tools is a parent of entries, so a rebuild (which is what Rails' remove_column does
# on SQLite) would delete every pick: down uses native DROP COLUMN.
class AddPairedModelsToTools < ActiveRecord::Migration[8.1]
  def up
    add_column :tools, :paired_models, :json, default: [], null: false
  end

  def down
    execute "ALTER TABLE tools DROP COLUMN paired_models"
  end
end
