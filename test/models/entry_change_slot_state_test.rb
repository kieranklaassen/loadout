require "test_helper"

# The slot state a change row carries (KTD7). Narration of the new actions is
# tested with the rest of the story in entry_change_test.rb.
class EntryChangeSlotStateTest < ActiveSupport::TestCase
  def change(overrides = {})
    EntryChange.new({ user: users(:every_fay), category: categories(:coding), tool: tools(:cursor), action: "set", source: "web", rank: 1 }.merge(overrides))
  end

  test "a change row carries the slot after the change and where it moved from" do
    row = change(ai_model: ai_models(:opus_5_5), rank: 2, from_rank: 1, context: "1m", effort: "high")

    saved = row.tap(&:save!).reload

    assert_equal [ 2, 1, "1m", "high" ], [ saved.rank, saved.from_rank, saved.context, saved.effort ]
  end

  test "every slot action and the system source are accepted, legacy actions still are" do
    (EntryChange::SLOT_ACTIONS + %w[suggested dismissed added updated made_primary]).each { |action| assert change(action:).valid?, action }
    assert change(source: "system", action: "baseline").valid?
    assert_not change(action: "rewrote").valid?
    assert_not change(source: "cron").valid?
  end

  test "suggested and dismissed rows are not slot changes" do
    assert_equal %w[set moved removed confirmed baseline], EntryChange::SLOT_ACTIONS
    assert_empty EntryChange::SLOT_ACTIONS & %w[suggested dismissed]
  end

  test "rank, from_rank, context and effort are checked, and legacy rows may leave them empty" do
    assert change(rank: nil, action: "added").valid?
    assert_not change(rank: 4).valid?
    assert_not change(from_rank: 0).valid?
    assert_not change(context: "500k").valid?
    assert_not change(effort: "extreme").valid?
  end
end
