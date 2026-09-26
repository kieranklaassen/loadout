# One line of a member's current loadout: in this category I use this tool,
# optionally with this model. Written only through Loadouts::Update.
class Entry < ApplicationRecord
  belongs_to :user
  belongs_to :category
  belongs_to :tool
  belongs_to :ai_model, optional: true

  validates :note, length: { maximum: 280 }
  validates :tool_id, uniqueness: { scope: %i[user_id category_id ai_model_id] }

  normalizes :note, with: ->(note) { note.squish.presence }

  scope :in_display_order, -> { joins(:category).order("categories.position", primary: :desc, created_at: :asc) }

  def to_prop
    {
      id:,
      category: category.slug,
      tool: tool.to_prop,
      model: ai_model&.to_prop,
      note:,
      primary:
    }
  end
end
