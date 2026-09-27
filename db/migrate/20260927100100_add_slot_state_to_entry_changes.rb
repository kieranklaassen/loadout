# A change row now stores the slot as it is after the change (tool, model, rank,
# context, effort) and, for moves, the rank it came from, so a person's state on
# any past day can be replayed. Legacy rows keep null and replay ignores them.
# entry_changes has no inbound foreign keys and every change here is a plain ALTER.
class AddSlotStateToEntryChanges < ActiveRecord::Migration[8.1]
  def up
    add_column :entry_changes, :rank, :integer
    add_column :entry_changes, :from_rank, :integer
    add_column :entry_changes, :context, :string
    add_column :entry_changes, :effort, :string
    add_index :entry_changes, %i[category_id user_id created_at], name: "index_entry_changes_for_replay"
  end

  def down
    remove_index :entry_changes, name: "index_entry_changes_for_replay"
    %w[effort context from_rank rank].each { |column| execute "ALTER TABLE entry_changes DROP COLUMN #{column}" }
  end
end
