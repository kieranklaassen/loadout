require "test_helper"

class PickSuggestionTest < ActiveSupport::TestCase
  def suggestion(overrides = {})
    PickSuggestion.new({ user: users(:every_dee), category: categories(:video), tool: tools(:runway), client_name: "Claude" }.merge(overrides))
  end

  test "a suggestion is a tool for a kind, with an optional model, context, effort and slot hint" do
    assert suggestion.valid?
    assert suggestion(ai_model: ai_models(:opus_5_5), context: "1m", effort: "low", slot_hint: 2).valid?
    assert_equal "open", suggestion.status
  end

  test "enums, statuses and ranks are checked" do
    assert_not suggestion(context: "500k").valid?
    assert_not suggestion(effort: "extreme").valid?
    assert_not suggestion(status: "confirmed-ish").valid?
    assert_not suggestion(slot_hint: 4).valid?
    assert_not suggestion(replaces_rank: 0).valid?
    assert suggestion(replaces_rank: 3, replaces_tool_id: tools(:cursor).id, replaces_ai_model_id: nil).valid?
    PickSuggestion::STATUSES.each { |status| assert suggestion(status:).valid?, status }
  end

  test "the database rejects values outside the lists" do
    { status: "confirmed-ish", context: "500k", effort: "extreme" }.each do |column, value|
      assert_raises(ActiveRecord::CheckViolation, column.to_s) { suggestion(column => value).save!(validate: false) }
    end
  end

  test "open picks the suggestions still waiting on the member" do
    dismissed = suggestion(status: "dismissed", resolved_at: Time.current).tap(&:save!)

    assert_includes PickSuggestion.open, pick_suggestions(:ana_runway)
    assert_not_includes PickSuggestion.open, dismissed
  end

  test "a member's suggestions are reachable from the member" do
    saved = suggestion.tap(&:save!)

    assert_includes users(:every_dee).pick_suggestions, saved
  end

  test "deleting a tool or a model takes its suggestions with it" do
    tool = Tool.create!(name: "Scratch tool", status: "pending", created_by: users(:every_dee))
    model = AiModel.create!(name: "Scratch model", status: "pending", created_by: users(:every_dee))
    suggestion(tool:, ai_model: model).save!

    assert_difference -> { PickSuggestion.count } => -1 do
      tool.destroy!
    end

    suggestion(ai_model: model).save!
    assert_difference -> { PickSuggestion.count } => -1 do
      model.destroy!
    end
  end
end
