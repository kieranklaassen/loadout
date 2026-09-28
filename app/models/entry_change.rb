# The dated history of a toolbox. Every change to a member's picks appends one
# row; the timeline, "recent changes" and the number-one history read from here.
#
# The legacy actions (added, removed, updated, made_primary) have no rank and stay
# readable. A slot-changing row stores the slot after the change (tool, model, rank,
# context, effort) and, for a move, the rank it came from; `removed` means that slot
# is now empty. Suggested and dismissed rows never touch a slot. Rows sharing a
# details["batch"] were written together and apply together. Baseline rows only
# rebuild state for replay; they are not events, so no story or recent list shows them.
class EntryChange < ApplicationRecord
  SLOT_ACTIONS = %w[set moved removed confirmed baseline].freeze
  ACTIONS = (%w[added updated made_primary suggested dismissed] + SLOT_ACTIONS).freeze
  SOURCES = %w[web mcp webmcp system].freeze
  PLACES = { 1 => "first", 2 => "second", 3 => "third" }.freeze

  belongs_to :user
  belongs_to :category
  belongs_to :tool
  belongs_to :ai_model, optional: true

  validates :action, inclusion: { in: ACTIONS }
  validates :source, inclusion: { in: SOURCES }
  validates :rank, :from_rank, numericality: { only_integer: true, in: 1..Entry::MAX_RANK }, allow_nil: true
  validates :context, inclusion: { in: Entry::CONTEXTS }, allow_nil: true
  validates :effort, inclusion: { in: Entry::EFFORTS }, allow_nil: true

  scope :recent_first, -> { order(created_at: :desc, id: :desc) }
  scope :narrated, -> { where.not(action: "baseline") }

  def subject
    [ tool.name, ai_model&.name ].compact.join(" with ")
  end

  # "Set Cursor with Claude Opus 5.5 as first pick for coding", in plain words. It
  # never raises: a read path must survive a row it has no sentence for. `client_name`
  # is untrusted text from an agent's registration and goes in as plain text.
  def sentence
    category_name = category.name.downcase
    case action
    when "added" then "Added #{subject} for #{category_name}"
    when "removed" then "Stopped using #{subject} for #{category_name}"
    when "made_primary" then "Made #{subject} the go-to for #{category_name}"
    when "updated" then "Updated the note on #{subject} for #{category_name}"
    when "set" then "Set #{pick_text} as #{place(rank)} for #{category_name}"
    when "moved" then "Moved #{subject}#{" from #{PLACES[from_rank]}" if PLACES[from_rank]} to #{place(rank)} for #{category_name}"
    when "confirmed" then "Confirmed #{pick_text} as #{place(rank)} for #{category_name}"
    when "suggested" then "#{client_name.presence || "An agent"} suggested #{pick_text} for #{category_name}"
    when "dismissed" then "Dismissed the suggestion of #{pick_text} for #{category_name}"
    when "baseline" then "Carried over #{pick_text} as #{place(rank)} for #{category_name}"
    else "Changed #{subject} for #{category_name}"
    end
  end

  def to_prop
    { id:, sentence:, action:, source:, client_name:, created_at: created_at.iso8601 }
  end

  # Human-readable history. Changes written together (one save, one agent call)
  # share a batch; within a batch, a removal plus an addition in the same
  # category read as one switch ("Switched coding model from Opus 5 to Claude
  # Opus 5.5"), and a go-to mark on something just added is folded in. Only the
  # legacy added and removed rows fold that way; a new row already says what the slot
  # holds now, so the rest read one line each. Baseline rows are left out.
  def self.story(changes)
    changes.reject { |change| change.action == "baseline" }.group_by { |change| change.details["batch"] || "change-#{change.id}" }.flat_map do |_batch, batch|
      batch.group_by(&:category_id).flat_map { |_category, group| narrate(group) }
    end.sort_by { |item| [ item[:created_at], item[:id] ] }.reverse
  end

  def self.narrate(group)
    removed = group.select { |change| change.action == "removed" }
    added = group.select { |change| change.action == "added" }
    consumed = Set.new
    items = []

    # Removed and re-added in one batch is no change at all.
    added.each do |addition|
      twin = removed.find { |change| !consumed.include?(change) && [ change.tool_id, change.ai_model_id ] == [ addition.tool_id, addition.ai_model_id ] }
      consumed << twin << addition if twin
    end

    added.each do |addition|
      next if consumed.include?(addition)

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

  private
    # "Cursor with Claude Opus 5.5 (1M context, high effort)".
    def pick_text
      setup = [ ("#{context.upcase} context" if context), ("#{effort} effort" if effort) ].compact
      setup.empty? ? subject : "#{subject} (#{setup.join(", ")})"
    end

    def place(rank)
      PLACES.key?(rank) ? "#{PLACES[rank]} pick" : "a pick"
    end
end
