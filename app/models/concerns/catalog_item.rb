# Shared shape of a Tool (Cursor, Runway) and an AiModel (Claude Opus 5.5).
# Approved items appear in pickers; pending items were added by a member and
# wait for admin review but already show on that member's loadout; hidden items
# leave the pickers and stay on existing entries.
module CatalogItem
  extend ActiveSupport::Concern

  STATUSES = %w[approved pending hidden].freeze

  included do
    belongs_to :created_by, class_name: "User", optional: true
    has_many :entries, dependent: :restrict_with_exception
    has_many :entry_changes, dependent: :restrict_with_exception
    has_many :pick_suggestions, dependent: :delete_all

    normalizes :name, with: ->(name) { name.squish }

    validates :slug, :name, :monogram, presence: true
    validates :slug, uniqueness: true
    validates :status, inclusion: { in: STATUSES }
    validates :hue, numericality: { only_integer: true, in: 0..359 }
    validates :name, length: { maximum: 60 }

    before_validation :fill_derived_fields
    after_update_commit :refresh_share_cards, if: -> { saved_change_to_name? || saved_change_to_mark? || saved_change_to_monogram? || saved_change_to_hue? }

    scope :approved, -> { where(status: "approved") }
    scope :pending, -> { where(status: "pending") }
    scope :pickable, -> { where(status: "approved") }
    # What a member's name or slug may match: anything but another member's pending
    # item, whose name stays as unknown to them as one nobody typed.
    scope :matchable_for, ->(user) { where.not(status: "pending").or(where(created_by: user)) }
    scope :ordered, -> { order(:position, :name) }
  end

  class_methods do
    def find_by_name_or_slug(value)
      key = value.to_s.squish
      return if key.blank?

      find_by(slug: key.downcase) || find_by(slug: key.parameterize) || where("lower(name) = ?", key.downcase).first
    end

    # Finds an item the member may be matched to by slug or name, or creates a pending
    # one of theirs for review (with its own slug when another member's shares the name).
    def resolve_or_suggest!(value, user:)
      matchable_for(user).find_by_name_or_slug(value) || create!(name: value.to_s.squish, status: "pending", created_by: user)
    end

    # A stable hue per name, so suggested items look intentional before review.
    def hue_for(name)
      Zlib.crc32(name.to_s.downcase) % 360
    end

    def monogram_for(name)
      words = name.to_s.scan(/[[:alnum:]]+/)
      letters = words.size > 1 ? words.first(2).map { |word| word[0] }.join : words.first.to_s[0, 2]
      letters.presence&.then { |value| value[0].upcase + value[1..].to_s.downcase } || "?"
    end
  end

  def pending?
    status == "pending"
  end

  def approved?
    status == "approved"
  end

  def to_prop
    { slug:, name:, kind:, maker:, mark:, pending: pending? }
  end

  private

  # Share cards are cached per member (ProfileCard); bump the members who show this item.
  def refresh_share_cards
    User.where(id: entries.select(:user_id)).update_all(updated_at: Time.current)
  end

  def fill_derived_fields
    return if name.blank?

    self.slug = unique_slug if slug.blank?
    self.monogram = self.class.monogram_for(name) if monogram.blank?
    self.hue = self.class.hue_for(name) if new_record? && hue == 220 && created_by_id.present?
  end

  def unique_slug
    base = name.parameterize.presence || "item"
    candidate = base
    counter = 2
    while self.class.exists?(slug: candidate)
      candidate = "#{base}-#{counter}"
      counter += 1
    end
    candidate
  end
end
