# An app or service people work in: Cursor, Claude Code, ChatGPT, Runway, ElevenLabs.
#
# paired_models lists the models the tool runs, each a model family (every model in
# it, now and later) or a model slug, the tool's own first. Empty means the catalog
# does not know, and every model stays equally likely.
class Tool < ApplicationRecord
  include CatalogItem

  def kind = "tool"

  def paired?
    paired_models.present?
  end

  # The approved models this tool runs, in the order paired_models lists them, then catalog order.
  # Pass `models` (approved, in catalog order) to pair many tools without a query each.
  def paired_ai_models(models = AiModel.pickable.ordered.to_a)
    keys = Array(paired_models)
    position = ->(model) { [ keys.index(model.family), keys.index(model.slug) ].compact.min }
    models.select(&position).sort_by.with_index { |model, index| [ position.(model), index ] }
  end
end
