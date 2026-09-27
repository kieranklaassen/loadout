require "test_helper"

class AiModelTest < ActiveSupport::TestCase
  test "newer_in_family lists newer approved models of the same family" do
    assert_equal [ ai_models(:opus_5_5) ], ai_models(:opus_5).newer_in_family
    assert_empty ai_models(:opus_5_5).newer_in_family
  end

  test "suggested items get a monogram and a stable hue" do
    item = AiModel.create!(name: "hedra character 3", status: "pending", created_by: users(:one))

    assert_equal "Hc", item.monogram
    assert_equal AiModel.hue_for("hedra character 3"), item.hue
    assert_equal "hedra-character-3", item.slug
  end

  test "resolve_or_suggest! adopts the item that won a concurrent slug insert" do
    with_lost_slug_race(slug: "hedra-character-3", name: "Hedra Character 3", monogram: "Hc", status: "pending") do
      item = AiModel.resolve_or_suggest!("hedra character 3", user: users(:one))

      assert_equal "hedra-character-3", item.slug
      assert item.pending?
    end
  end

  test "release dates beat catalog order when both models have one" do
    ai_models(:opus_5_5).update!(released_on: Date.new(2026, 5, 1))
    ai_models(:opus_5).update!(released_on: Date.new(2026, 8, 1))

    assert ai_models(:opus_5).newer_than?(ai_models(:opus_5_5))
    assert_equal [ ai_models(:opus_5) ], ai_models(:opus_5_5).newer_in_family
    assert_not ai_models(:gpt_6).newer_than?(ai_models(:opus_5))
  end

  private

  # Stands in for another member suggesting the same name between the slug lookup
  # and the insert: the row lands, then this insert loses the unique index.
  # Minitest 6 dropped Object#stub and the repo carries no mocking gem, so create!
  # is overridden on the singleton and removed afterwards.
  def with_lost_slug_race(row)
    patched = false
    singleton = AiModel.singleton_class

    singleton.send(:define_method, :create!) do |*, **|
      insert!(row.merge(created_at: Time.current, updated_at: Time.current))
      raise ActiveRecord::RecordNotUnique, "UNIQUE constraint failed: ai_models.slug"
    end
    patched = true

    yield
  ensure
    # create! is inherited, so dropping the override reveals the real one again.
    singleton.send(:remove_method, :create!) if patched
  end
end
