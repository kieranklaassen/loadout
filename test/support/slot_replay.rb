# A person's slots at the end of their change history, rebuilt from entry_changes
# rows the way KTD7 defines it: rows apply in created_at then id order, rows that
# share a timestamp and a details.batch apply together (clear the removed and
# from_rank slots first, then set the rest), and only slot-changing actions count.
# Written independently of the app's read layer so a test can hold that layer to it.
module SlotReplay
  SLOT_ACTIONS = %w[set moved removed confirmed baseline].freeze

  # rows: hashes with string keys (id, category_id, action, rank, from_rank, tool_id,
  # ai_model_id, context, effort, details, created_at). Returns
  # { [category_id, rank] => [tool_id, ai_model_id, context, effort] }.
  def replay_slots(rows)
    slots = {}
    changes = rows.select { |row| SLOT_ACTIONS.include?(row["action"]) && row["rank"] }
    batches = changes.sort_by { |row| [ replay_time(row["created_at"]), row["id"] ] }.chunk_while do |a, b|
      replay_time(a["created_at"]) == replay_time(b["created_at"]) && replay_batch(a) == replay_batch(b)
    end

    batches.each do |batch|
      batch.each do |row|
        slots.delete([ row["category_id"], row["from_rank"] ]) if row["from_rank"]
        slots.delete([ row["category_id"], row["rank"] ]) if row["action"] == "removed"
      end
      batch.reject { |row| row["action"] == "removed" }.each do |row|
        slots[[ row["category_id"], row["rank"] ]] = [ row["tool_id"], row["ai_model_id"], row["context"], row["effort"] ]
      end
    end
    slots
  end

  private

  def replay_time(value)
    value.is_a?(String) ? Time.find_zone!("UTC").parse(value) : value.to_time
  end

  def replay_batch(row)
    details = row["details"]
    details = JSON.parse(details) if details.is_a?(String)
    details.to_h["batch"]
  end
end

ActiveSupport.on_load(:active_support_test_case) { include SlotReplay }
