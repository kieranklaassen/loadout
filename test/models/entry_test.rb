require "test_helper"

class EntryTest < ActiveSupport::TestCase
  def pick(overrides = {})
    Entry.new({ user: users(:every_fay), category: categories(:knowledge_work), tool: tools(:claude), rank: 1 }.merge(overrides))
  end

  test "a pick is a tool at a rank from 1 to 3, with an optional model, context and effort" do
    assert pick.valid?
    assert pick(ai_model: ai_models(:opus_5_5), context: "1m", effort: "high").valid?
    assert pick(rank: 3).valid?
  end

  test "a rank outside 1 to 3 is rejected" do
    [ 0, 4, -1, nil, 1.5 ].each { |rank| assert_not pick(rank:).valid?, "rank #{rank.inspect}" }
  end

  test "context and effort come from their lists; blank means none" do
    assert_not pick(context: "500k").valid?
    assert_not pick(effort: "extreme").valid?

    entry = pick(context: " 1M ", effort: "")
    assert_equal [ "1m", nil ], [ entry.context, entry.effort ]
    assert entry.valid?
  end

  test "a second pick at the same rank in a kind is rejected by the model and by the database" do
    duplicate = pick(user: users(:every_ana), category: categories(:coding), tool: tools(:runway), rank: 1)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:rank], "has already been taken"
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end

  test "the same tool twice in a kind is rejected by the model and by the database, even with different models" do
    duplicate = pick(user: users(:every_ana), category: categories(:coding), tool: tools(:cursor), ai_model: ai_models(:gpt_6), rank: 3)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:tool_id], "has already been taken"
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end

  test "the same tool may appear in different kinds, and other people may hold the same rank" do
    assert pick(user: users(:every_ana), category: categories(:video), tool: tools(:cursor), rank: 1).valid?
    assert pick(user: users(:every_fay), category: categories(:coding), tool: tools(:cursor), rank: 2).valid?
  end

  test "the database requires a rank" do
    entry = pick(rank: nil)
    assert_raises(ActiveRecord::NotNullViolation) { entry.save!(validate: false) }
  end

  test "to_prop is the pick shape" do
    entry = entries(:ana_cursor)

    assert_equal({ rank: 1, tool: tools(:cursor).to_prop, model: ai_models(:opus_5_5).to_prop, context: "1m", effort: "high" }, entry.to_prop)
    assert_equal({ rank: 2, tool: tools(:claude_code).to_prop, model: nil, context: nil, effort: nil }, entries(:ana_claude_code).to_prop)
  end

  test "picks list by kind position, then rank" do
    ranks = users(:every_ana).entries.in_display_order.map { |entry| [ entry.category.slug, entry.rank ] }

    assert_equal [ [ "coding", 1 ], [ "coding", 2 ], [ "knowledge-work", 1 ] ], ranks
  end

  test "every fixture person's change history replays to exactly their picks" do
    User.find_each do |person|
      changes = person.entry_changes.map { |change| change.attributes.merge("details" => change.details) }
      expected = person.entries.to_h { |entry| [ [ entry.category_id, entry.rank ], [ entry.tool_id, entry.ai_model_id, entry.context, entry.effort ] ] }

      assert_equal expected, replay_slots(changes), person.email_address
    end
  end

  test "starting to share changes who may see a person's history, not the history itself" do
    hidden = users(:every_cy)
    hidden.update!(visibility: "team")

    changes = hidden.entry_changes.map { |change| change.attributes.merge("details" => change.details) }
    expected = hidden.entries.to_h { |entry| [ [ entry.category_id, entry.rank ], [ entry.tool_id, entry.ai_model_id, entry.context, entry.effort ] ] }
    assert_equal expected, replay_slots(changes)
    assert_equal [ "team", "team" ], hidden.visibility_periods.order(:starts_at).pluck(:level), "the earlier team span is kept beside the new one"
  end

  test "an open suggestion is not a pick, so no query over entries can show it" do
    suggestion = pick_suggestions(:ana_runway)

    assert_not Entry.exists?(user: suggestion.user, category: suggestion.category)
  end
end
