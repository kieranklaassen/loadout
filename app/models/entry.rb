# One confirmed pick in a member's loadout: in this kind of work, at this rank
# (1 to 3), I use this tool, optionally with a model, a context size and an effort.
# Written only through Loadouts::Update; an agent's proposal is a PickSuggestion
# until the member confirms it, so every reader of entries sees confirmed picks only.
class Entry < ApplicationRecord
  MAX_RANK = 3
  CONTEXTS = %w[200k 1m].freeze
  EFFORTS = %w[low medium high].freeze

  belongs_to :user
  belongs_to :category
  belongs_to :tool
  belongs_to :ai_model, optional: true

  normalizes :context, :effort, with: ->(value) { value.to_s.strip.downcase.presence }

  # The database keeps rank and tool unique per person and kind; a rank has no upper
  # bound there because a swap parks a row above the last rank for a moment.
  validates :rank, numericality: { only_integer: true, in: 1..MAX_RANK }
  validates :rank, :tool_id, uniqueness: { scope: %i[user_id category_id] }
  validates :context, inclusion: { in: CONTEXTS }, allow_nil: true
  validates :effort, inclusion: { in: EFFORTS }, allow_nil: true

  scope :in_display_order, -> { joins(:category).order("categories.position", :rank) }

  def to_prop
    { rank:, tool: tool.to_prop, model: ai_model&.to_prop, context:, effort: }
  end
end
