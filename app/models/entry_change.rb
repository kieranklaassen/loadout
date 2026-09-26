# The dated history of a loadout. Every add, removal, note edit, or primary
# switch appends one row; the timeline and "recent changes" read from here.
class EntryChange < ApplicationRecord
  ACTIONS = %w[added removed updated made_primary].freeze
  SOURCES = %w[web mcp webmcp].freeze

  belongs_to :user
  belongs_to :category
  belongs_to :tool
  belongs_to :ai_model, optional: true

  validates :action, inclusion: { in: ACTIONS }
  validates :source, inclusion: { in: SOURCES }

  scope :recent_first, -> { order(created_at: :desc, id: :desc) }

  def subject
    [ tool.name, ai_model&.name ].compact.join(" with ")
  end

  # "Added Cursor with Claude Opus 5.5 for coding", in plain words.
  def sentence
    category_name = category.name.downcase
    case action
    when "added" then "Added #{subject} for #{category_name}"
    when "removed" then "Stopped using #{subject} for #{category_name}"
    when "made_primary" then "Made #{subject} the go-to for #{category_name}"
    when "updated" then "Updated the note on #{subject} for #{category_name}"
    else raise ArgumentError, "unknown action #{action}"
    end
  end

  def to_prop
    { id:, sentence:, action:, source:, client_name:, created_at: created_at.iso8601 }
  end

  # Human-readable history. Changes written together (one save, one agent call)
  # share a batch; within a batch, a removal plus an addition in the same
  # category read as one switch ("Switched coding model from Opus 5 to Claude
  # Opus 5.5"), and a go-to mark on something just added is folded in.
  def self.story(changes)
    changes.group_by { |change| change.details["batch"] || "change-#{change.id}" }.flat_map do |_batch, batch|
      batch.group_by(&:category_id).flat_map { |_category, group| narrate(group) }
    end.sort_by { |item| [ item[:created_at], item[:id] ] }.reverse
  end

  def self.narrate(group)
    removed = group.select { |change| change.action == "removed" }
    added = group.select { |change| change.action == "added" }
    consumed = Set.new
    items = []

    added.each do |addition|
      removal = removed.find { |change| change.tool_id == addition.tool_id && !consumed.include?(change) }
      removal ||= removed.first if removed.one? && added.one?
      next if removal.nil? || consumed.include?(removal)

      consumed << removal << addition
      items << switch_item(removal, addition)
    end

    added_keys = added.map { |change| [ change.tool_id, change.ai_model_id ] }
    group.each do |change|
      next if consumed.include?(change)
      next if change.action == "made_primary" && added_keys.include?([ change.tool_id, change.ai_model_id ])

      items << change.to_prop
    end
    items
  end

  def self.switch_item(removal, addition)
    category_name = addition.category.name.downcase
    sentence =
      if removal.tool_id == addition.tool_id && addition.ai_model
        from = removal.ai_model ? " from #{removal.ai_model.name}" : ""
        "Switched #{category_name} model#{from} to #{addition.ai_model.name} in #{addition.tool.name}"
      else
        "Switched #{category_name} from #{removal.subject} to #{addition.subject}"
      end
    addition.to_prop.merge(sentence:, action: "switched")
  end
  private_class_method :narrate, :switch_item
end
