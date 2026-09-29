# What an agent proposes, kept apart from entries so every reader of entries sees
# only confirmed picks. A suggestion that would change an occupied slot stores a
# snapshot of it (replaces_*) instead of a foreign key to entries, so this table
# depends on nothing that entries rebuilds.
class CreatePickSuggestions < ActiveRecord::Migration[8.1]
  def change
    create_table :pick_suggestions do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :category, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :tool, null: false, foreign_key: { on_delete: :cascade }
      t.references :ai_model, foreign_key: { on_delete: :cascade }
      t.string :context
      t.string :effort
      t.integer :slot_hint
      t.integer :replaces_rank
      t.integer :replaces_tool_id
      t.integer :replaces_ai_model_id
      t.integer :oauth_client_id
      t.string :client_name
      t.string :status, null: false, default: "open"
      t.datetime :resolved_at
      t.timestamps

      t.check_constraint "status IN ('open', 'confirmed', 'dismissed', 'withdrawn', 'superseded', 'expired')", name: "pick_suggestions_status_check"
      t.check_constraint "context IS NULL OR context IN ('200k', '1m')", name: "pick_suggestions_context_check"
      t.check_constraint "effort IS NULL OR effort IN ('low', 'medium', 'high')", name: "pick_suggestions_effort_check"
    end
    add_index :pick_suggestions, %i[user_id category_id status]
    add_index :pick_suggestions, %i[user_id oauth_client_id status], name: "index_pick_suggestions_on_client"
  end
end
