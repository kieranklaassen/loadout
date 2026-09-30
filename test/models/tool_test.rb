require "test_helper"

class ToolTest < ActiveSupport::TestCase
  test "paired models are the approved models of the listed families and slugs, in the order listed" do
    tool = tools(:runway)
    tool.update!(paired_models: %w[gpt-6-astra claude-opus])
    ai_models(:opus_5).update!(status: "hidden")

    assert tool.paired?
    assert_equal %w[gpt-6-astra claude-opus-5-5], tool.paired_ai_models.map(&:slug)
  end

  test "a tool that lists nothing pairs with nothing" do
    assert_not tools(:cursor).paired?
    assert_empty tools(:cursor).paired_ai_models
  end
end
