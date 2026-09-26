# SQLite treats NULLs as distinct in the entries uniqueness index, so a pick
# without a model needs its own partial index to stay unique under concurrency.
class AddUniqueModellessEntriesIndex < ActiveRecord::Migration[8.1]
  def change
    add_index :entries, %i[user_id category_id tool_id], unique: true, where: "ai_model_id IS NULL", name: "index_entries_uniqueness_without_model"
  end
end
