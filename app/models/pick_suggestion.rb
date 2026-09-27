# What an agent proposes for a member's loadout. It lives apart from Entry so that
# nothing which reads confirmed picks can show an unconfirmed one; only the owner
# sees it, and only the owner, on the web, can confirm or dismiss it. A suggestion
# that would change an occupied slot carries a snapshot of that slot (replaces_*)
# instead of a foreign key, and rows are never edited once listed.
class PickSuggestion < ApplicationRecord
  STATUSES = %w[open confirmed dismissed withdrawn superseded expired].freeze
  # An unconfirmed suggestion lapses this long after it was made; the row is kept.
  TTL = 30.days

  belongs_to :user
  belongs_to :category
  belongs_to :tool
  belongs_to :ai_model, optional: true
  belongs_to :replaces_tool, class_name: "Tool", optional: true
  belongs_to :replaces_ai_model, class_name: "AiModel", optional: true

  normalizes :context, :effort, with: ->(value) { value.to_s.strip.downcase.presence }

  validates :status, inclusion: { in: STATUSES }
  validates :context, inclusion: { in: Entry::CONTEXTS }, allow_nil: true
  validates :effort, inclusion: { in: Entry::EFFORTS }, allow_nil: true
  validates :slot_hint, :replaces_rank, numericality: { only_integer: true, in: 1..Entry::MAX_RANK }, allow_nil: true

  # Still waiting on the member. A suggestion past its TTL is out even before
  # anything has marked it expired.
  scope :open, -> { where(status: "open", created_at: TTL.ago..) }
end
