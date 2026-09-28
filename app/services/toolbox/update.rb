# frozen_string_literal: true

# The one write path for toolboxes: the web editor, MCP agents and WebMCP all call
# this. It changes `entries` (confirmed picks) or `pick_suggestions` (an agent's
# proposals) and appends `entry_changes` (the dated history) in one transaction, so
# the history always replays to the toolbox (KTD7).
#
# The boundary is the `source`, which the server sets per transport and no caller
# can argue with (KTD2): only "web" runs WEB_OPERATIONS, the member's own decisions;
# every source may run AGENT_OPERATIONS, which never touch a confirmed pick.
#
#   { op: "set_pick", category: "coding", rank: 1, tool: "cursor", model: "claude-opus-5-5", context: "1m", effort: "high", expected_tool: nil }
#   { op: "remove_pick", category: "coding", rank: 2, expected_tool: "cursor" }
#   { op: "move_pick", category: "coding", rank: 2, direction: "up", expected_tool: "cursor" }
#   { op: "confirm", suggestion_id: 12, rank: 2, expected: { tool: "cursor", model: nil } }
#   { op: "dismiss", suggestion_id: 12 }
#   { op: "suggest", category: "coding", tool: "cursor", model: "claude-opus-5-5", context: "1m", effort: "high", rank: 1 }
#   { op: "withdraw", suggestion_id: 12 }
#
# Tools, models and kinds go by slug or name. On set_pick, a key left out keeps what
# the slot holds and a key sent as null clears it. expected_tool is the slug of the
# tool the member was shown at that rank, or null for an empty slot; if the slot now
# holds anything else the call fails with Suggestions::CHANGED and writes nothing.
# Leave it out (seeds, the console) to skip that check. Unknown tools and models, and
# another member's pending ones, become this member's pending catalog items; agents
# may add a few a day. Raises Toolbox::Update::Error
# with a message a person or an agent can act on.
module Toolbox
  class Update
    class Error < StandardError; end

    WEB_OPERATIONS = %w[set_pick remove_pick move_pick confirm dismiss].freeze
    AGENT_OPERATIONS = %w[suggest withdraw].freeze
    OPERATIONS = (WEB_OPERATIONS + AGENT_OPERATIONS).freeze
    MAX_OPERATIONS = 50
    MAX_NEW_ITEMS_PER_DAY = 5
    CHOICES = { context: Entry::CONTEXTS, effort: Entry::EFFORTS }.freeze

    # changes: entry_changes rows written; suggestions: the suggestion rows created or
    # closed, as they stand when the call ends; messages: plain-words notes for operations that had nothing to do.
    Result = Data.define(:changes, :suggestions, :messages, :user)

    def self.call(...) = new(...).call

    def initialize(user:, operations:, source:, client_name: nil, oauth_client_id: nil)
      @user = user
      @operations = Array.wrap(operations).map { |operation| operation.to_h.with_indifferent_access }
      @source = source.to_s
      @client_name = client_name.presence
      @oauth_client_id = oauth_client_id
      @changes = []
      @suggestion_rows = []
      @messages = []
    end

    def call
      raise Error, "Send at least one operation." if @operations.empty?
      raise Error, "Send at most #{MAX_OPERATIONS} operations at a time." if @operations.size > MAX_OPERATIONS
      raise ArgumentError, "unknown source #{@source}" unless EntryChange::SOURCES.include?(@source)

      @operations.each { |operation| check_allowed(operation[:op].to_s) }

      ApplicationRecord.transaction do
        @operations.each { |operation| apply(operation) }
        # Supersession closes rows with update_all, so a row created earlier in this call can be stale.
        @suggestion_rows.each(&:reload)
        @user.update!(loadout_updated_at: Time.current) if @changes.any? { |change| EntryChange::SLOT_ACTIONS.include?(change.action) }
      end

      Result.new(changes: @changes, suggestions: @suggestion_rows, messages: @messages, user: @user)
    rescue ActiveRecord::RecordInvalid => e
      raise Error, e.record.errors.full_messages.to_sentence
    rescue ActiveRecord::RecordNotUnique
      raise Error, "That slot changed while you were saving. Reload and try again."
    end

    private

    # Before any write, so a forbidden operation anywhere in the list stops the lot.
    def check_allowed(op)
      allowed = @source == "web" ? OPERATIONS : AGENT_OPERATIONS
      raise Error, "#{op} can only be done by the member on the web." if WEB_OPERATIONS.include?(op) && @source != "web"
      raise Error, "Unknown operation #{op.inspect}. Use one of: #{allowed.join(", ")}." unless allowed.include?(op)
    end

    def apply(operation)
      case operation[:op].to_s
      when "set_pick" then set_pick(operation)
      when "remove_pick" then remove_pick(operation)
      when "move_pick" then move_pick(operation)
      when "confirm" then absorb(suggestions.confirm(suggestion_id(operation), rank: optional_rank(operation, "Send a rank from 1 to 3."), expected: operation[:expected]))
      when "dismiss" then absorb(suggestions.dismiss(suggestion_id(operation)))
      when "suggest" then suggest(operation)
      when "withdraw" then absorb(suggestions.withdraw(suggestion_id(operation)))
      end
    end

    def set_pick(operation)
      slots = slots_for(operation)
      rank = rank_from(operation)
      existing = check_slot(slots, rank, operation)
      tool = operation.key?(:tool) ? resolve(Tool, operation[:tool], required: true) : existing&.tool || raise(Error, "Name a tool.")
      ai_model = operation.key?(:model) ? resolve(AiModel, operation[:model]) : existing&.ai_model
      context = operation.key?(:context) ? choice(:context, operation[:context]) : existing&.context
      effort = operation.key?(:effort) ? choice(:effort, operation[:effort]) : existing&.effort

      change = slots.place(rank:, tool:, ai_model:, context:, effort:)
      @changes << change if change
    end

    def remove_pick(operation)
      slots = slots_for(operation)
      rank = rank_from(operation)
      check_slot(slots, rank, operation)
      @changes.concat(slots.remove(rank:))
    end

    def move_pick(operation)
      direction = operation[:direction].to_s
      raise Error, "Direction must be up or down." unless %w[up down].include?(direction)

      slots = slots_for(operation)
      rank = rank_from(operation)
      check_slot(slots, rank, operation)
      @changes.concat(slots.move(rank:, direction:))
    end

    # Returns the pick in the slot at `rank`. When the operation sends expected_tool, the
    # tool the member was shown there (nil for an empty slot), the slot must still hold
    # it: a retry or a second tab must not act on whatever has moved into that rank since.
    def check_slot(slots, rank, operation)
      entry = slots.entries.find { |candidate| candidate.rank == rank }
      raise Error, Suggestions::CHANGED if operation.key?(:expected_tool) && entry&.tool&.slug.to_s != operation[:expected_tool].to_s

      entry
    end

    def suggest(operation)
      category = category_for(operation)
      tool = resolve(Tool, operation[:tool], required: true)
      absorb(suggestions.suggest(
        category:, tool:, ai_model: resolve(AiModel, operation[:model]),
        context: choice(:context, operation[:context]), effort: choice(:effort, operation[:effort]),
        slot_hint: optional_rank(operation, "A rank hint must be 1, 2 or 3.")
      ))
    end

    def absorb(outcome)
      @changes.concat(outcome.changes)
      @suggestion_rows << outcome.suggestion if outcome.suggestion
      @messages << outcome.message if outcome.message
    end

    def slots_for(operation)
      Slots.new(user: @user, category: category_for(operation), source: @source, client_name: @client_name)
    end

    def suggestions
      @suggestions ||= Suggestions.new(user: @user, source: @source, client_name: @client_name, oauth_client_id: @oauth_client_id)
    end

    def category_for(operation)
      Category.resolve(operation[:category]) ||
        raise(Error, "Unknown category #{operation[:category].inspect}. Use one of: #{Category.pluck(:slug).join(", ")}.")
    end

    def rank_from(operation)
      Integer(operation[:rank].to_s, exception: false) || raise(Error, "Send a rank from 1 to 3.")
    end

    def optional_rank(operation, message)
      return if operation[:rank].blank?

      rank = Integer(operation[:rank].to_s, exception: false)
      raise Error, message unless rank&.between?(1, Entry::MAX_RANK)

      rank
    end

    def suggestion_id(operation)
      operation[:suggestion_id].presence || raise(Error, "Send the suggestion_id.")
    end

    def choice(field, value)
      normalized = Entry.normalize_value_for(field, value)
      return normalized if normalized.nil? || CHOICES.fetch(field).include?(normalized)

      raise Error, "#{field.to_s.capitalize} must be one of #{CHOICES.fetch(field).to_sentence(two_words_connector: " or ", last_word_connector: " or ")}."
    end

    def resolve(klass, value, required: false)
      if value.blank?
        raise Error, "Name a #{klass == Tool ? "tool" : "model"}." if required
        return
      end

      klass.matchable_for(@user).find_by_name_or_slug(value) || create_pending(klass, value)
    end

    def create_pending(klass, value)
      if @source != "web" && new_items_today >= MAX_NEW_ITEMS_PER_DAY
        raise Error, "Agents can add #{MAX_NEW_ITEMS_PER_DAY} new tools or models a day and that limit is reached. Pick one from the catalog, or ask the member to add it."
      end

      klass.resolve_or_suggest!(value, user: @user)
    end

    def new_items_today
      [ Tool, AiModel ].sum { |klass| klass.pending.where(created_by: @user, created_at: 1.day.ago..).count }
    end
  end
end
