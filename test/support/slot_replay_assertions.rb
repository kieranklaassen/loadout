# Holds the write path to the history contract (KTD7): replaying a person's
# entry_changes rows must give back exactly their entries. Uses the
# independent replay in slot_replay.rb, never app code.
module SlotReplayAssertions
  def assert_replays_to_entries(user, message = nil)
    replayed = replay_slots(user.entry_changes.map(&:attributes))
    current = user.entries.reload.to_h do |entry|
      [ [ entry.category_id, entry.rank ], [ entry.tool_id, entry.ai_model_id, entry.context, entry.effort ] ]
    end

    assert_equal current, replayed, message || "the change rows should replay to the entries"
  end

  def assert_no_rank_above_the_limit
    assert_operator Entry.maximum(:rank).to_i, :<=, Entry::MAX_RANK, "a parked rank was left behind"
  end
end

ActiveSupport.on_load(:active_support_test_case) { include SlotReplayAssertions }
