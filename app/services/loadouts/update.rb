# frozen_string_literal: true

# The one write path for loadouts: the web pickers, MCP agents, and WebMCP all
# call this. It changes `entries` (the current state) and appends
# `entry_changes` (the dated history) in one transaction, so the history can
# always rebuild the loadout.
#
# Operations (string or symbol keys; tools and models by slug or name):
#
#   { op: "add", category: "coding", tool: "cursor", model: "claude-opus-5-5", note: "...", primary: true }
#   { op: "remove", category: "coding", tool: "cursor", model: "claude-opus-5-5" }
#   { op: "set_primary", category: "coding", tool: "cursor", model: nil }
#   { op: "update_note", category: "coding", tool: "cursor", model: nil, note: "..." }
#   { op: "replace_category", category: "coding", picks: [ { tool: "cursor", model: "...", primary: true, note: "..." } ] }
#
# Unknown tools and models become pending catalog items (Catalog review).
# Raises Loadouts::Update::Error with a message an agent or a person can act on.
module Loadouts
  class Update
    class Error < StandardError; end

    OPERATIONS = %w[add remove set_primary update_note replace_category].freeze
    MAX_OPERATIONS = 50

    Result = Data.define(:changes, :user)

    def self.call(...) = new(...).call

    def initialize(user:, operations:, source:, client_name: nil)
      @user = user
      @operations = Array.wrap(operations).map { |operation| operation.to_h.with_indifferent_access }
      @source = source.to_s
      @client_name = client_name.presence
      @batch = SecureRandom.uuid
      @changes = []
    end

    def call
      raise Error, "Send at least one operation." if @operations.empty?
      raise Error, "Send at most #{MAX_OPERATIONS} operations at a time." if @operations.size > MAX_OPERATIONS
      raise ArgumentError, "unknown source #{@source}" unless EntryChange::SOURCES.include?(@source)

      ApplicationRecord.transaction do
        @operations.each { |operation| apply(operation) }
        touched_categories.each { |category| ensure_one_primary(category) }
        @user.update!(loadout_updated_at: Time.current) if @changes.any?
      end

      Result.new(changes: @changes, user: @user)
    rescue ActiveRecord::RecordInvalid => e
      raise Error, e.record.errors.full_messages.to_sentence
    end

    private

    def apply(operation)
      op = operation[:op].to_s
      raise Error, "Unknown operation #{op.inspect}. Use one of: #{OPERATIONS.join(", ")}." unless OPERATIONS.include?(op)

      category = category_for(operation)
      case op
      when "add" then add(category, operation)
      when "remove" then remove(category, operation)
      when "set_primary" then set_primary(find_entry!(category, operation))
      when "update_note" then update_note(find_entry!(category, operation), operation[:note])
      when "replace_category" then replace_category(category, Array.wrap(operation[:picks]))
      end
    end

    def add(category, pick)
      tool = resolve(Tool, pick[:tool], required: true)
      model = resolve(AiModel, pick[:model])
      entry = @user.entries.find_or_initialize_by(category:, tool:, ai_model: model)

      if entry.new_record?
        entry.note = pick[:note]
        entry.save!
        record("added", entry)
      elsif pick.key?(:note) && entry.note != Entry.normalize_value_for(:note, pick[:note])
        update_note(entry, pick[:note])
      end

      set_primary(entry) if ActiveModel::Type::Boolean.new.cast(pick[:primary])
      entry
    end

    def remove(category, operation)
      entry = find_entry!(category, operation)
      record("removed", entry)
      entry.destroy!
    end

    def set_primary(entry)
      return if entry.primary?

      @user.entries.where(category: entry.category, primary: true).update_all(primary: false)
      entry.update!(primary: true)
      record("made_primary", entry)
    end

    def update_note(entry, note)
      entry.update!(note:)
      record("updated", entry) if entry.saved_change_to_note?
    end

    def replace_category(category, picks)
      kept = picks.map do |pick|
        pick = pick.to_h.with_indifferent_access
        add(category, pick)
      end
      @user.entries.where(category:).where.not(id: kept.map(&:id)).find_each do |entry|
        record("removed", entry)
        entry.destroy!
      end
    end

    def ensure_one_primary(category)
      entries = @user.entries.where(category:)
      return if entries.none? || entries.exists?(primary: true)

      entries.order(:created_at, :id).first.update!(primary: true)
    end

    def find_entry!(category, operation)
      tool = resolve(Tool, operation[:tool], required: true, create: false)
      model = resolve(AiModel, operation[:model], create: false)
      scope = @user.entries.where(category:, tool:)
      entry = operation[:model].present? ? scope.find_by(ai_model: model) : (scope.find_by(ai_model: nil) || (scope.one? && scope.first))
      entry || raise(Error, "#{[ operation[:tool], operation[:model] ].compact_blank.join(" with ")} is not in your #{category.name.downcase} loadout.")
    end

    def category_for(operation)
      Category.resolve(operation[:category]) ||
        raise(Error, "Unknown category #{operation[:category].inspect}. Use one of: #{Category.pluck(:slug).join(", ")}.")
    end

    def resolve(klass, value, required: false, create: true)
      if value.blank?
        raise Error, "Name a #{klass == Tool ? "tool" : "model"}." if required
        return
      end

      item = create ? klass.resolve_or_suggest!(value, user: @user) : klass.find_by_name_or_slug(value)
      item || raise(Error, "Unknown #{klass == Tool ? "tool" : "model"} #{value.to_s.inspect}.")
    end

    def touched_categories
      @touched_categories ||= Category.where(id: @changes.map(&:category_id).uniq).to_a
    end

    def record(action, entry)
      @touched_categories = nil
      @changes << EntryChange.create!(
        user: @user, category: entry.category, tool: entry.tool, ai_model: entry.ai_model,
        action:, source: @source, client_name: @client_name, details: { batch: @batch }
      )
    end
  end
end
