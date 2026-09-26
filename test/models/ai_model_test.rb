require "test_helper"

class AiModelTest < ActiveSupport::TestCase
  test "newer_in_family lists newer approved models of the same family" do
    assert_equal [ ai_models(:opus_5_5) ], ai_models(:opus_5).newer_in_family.to_a
    assert_empty ai_models(:opus_5_5).newer_in_family
  end

  test "suggested items get a monogram and a stable hue" do
    item = AiModel.create!(name: "hedra character 3", status: "pending", created_by: users(:one))

    assert_equal "Hc", item.monogram
    assert_equal AiModel.hue_for("hedra character 3"), item.hue
    assert_equal "hedra-character-3", item.slug
  end
end
