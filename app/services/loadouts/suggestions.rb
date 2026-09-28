# frozen_string_literal: true

# What an agent may propose and what only the member decides (R10, KTD10, KTD18).
# An agent's pick is a PickSuggestion row, never an entry; the member confirms or
# dismisses it on the web, and a row is never edited once listed, so "suggest"
# always inserts a new one. Loadouts::Update calls this for the suggest, withdraw,
# confirm and dismiss operations.
#
# Rules: at most MAX_OPEN_PER_KIND open per kind (the oldest gives way); a newer
# suggestion from the same OAuth client id for the same kind and tool replaces that
# client's older one (WebMCP has no client id and is one bucket of its own); an
# identical suggestion the member dismissed is refused for DISMISSAL_MEMORY; an
# unconfirmed one lapses after PickSuggestion::TTL. Placement is decided at confirm:
# the hint if that slot is empty, else the first empty one, else the member says which
# pick to replace. Superseded, withdrawn and expired suggestions write no change row.
module Loadouts
  class Suggestions
    MAX_OPEN_PER_KIND = 3
    DISMISSAL_MEMORY = 30.days
    CHANGED = "This changed, review it."
    NO_LONGER_OPEN = "That suggestion is no longer open."
    UNNAMED_AGENT = "An agent"

    # changes: entry_changes rows written; suggestion: the row acted on; message: a
    # plain-words note when there was nothing to do.
    Outcome = Data.define(:changes, :suggestion, :message) do
      def initialize(changes: [], suggestion: nil, message: nil) = super
    end

    # Withdraws every open suggestion the client made for the member: called when
    # the member disconnects the client. Returns how many were withdrawn.
    def self.withdraw_for_client(user:, oauth_client:)
      now = Time.current
      user.pick_suggestions.open.where(oauth_client_id: oauth_client.id).update_all(status: "withdrawn", resolved_at: now, updated_at: now)
    end

    # The slot a suggestion would land in: where its tool already sits in the kind,
    # else its hint when empty, else the first empty slot, else nil (the member picks).
    def self.target_rank(suggestion, entries)
      current = entries.find { |entry| entry.tool_id == suggestion.tool_id }
      return current.rank if current

      empty = (1..Entry::MAX_RANK).to_a - entries.map(&:rank)
      empty.include?(suggestion.slot_hint) ? suggestion.slot_hint : empty.first
    end

    def initialize(user:, source:, client_name:, oauth_client_id:)
      @user = user
      @source = source
      @client_name = client_name
      @oauth_client_id = oauth_client_id
    end

    def suggest(category:, tool:, ai_model:, context:, effort:, slot_hint:)
      expire_lapsed
      slots = slots_for(category, client_name: label)
      current = slots.entries.find { |entry| entry.tool_id == tool.id }
      if current && same_pick?(current, ai_model, context, effort)
        return Outcome.new(message: "#{tool.name} is already your #{current.rank.ordinalize} pick for #{category.name.downcase} with those details.")
      end

      refuse_if_dismissed(category, tool, ai_model, context, effort)
      close(open_in(category).where(tool:, oauth_client_id: @oauth_client_id), "superseded")
      make_room(category)
      suggestion = @user.pick_suggestions.create!(
        category:, tool:, ai_model:, context:, effort:, slot_hint:, client_name: label, oauth_client_id: @oauth_client_id,
        replaces_rank: current&.rank, replaces_tool_id: current&.tool_id, replaces_ai_model_id: current&.ai_model_id
      )
      Outcome.new(changes: [ slots.record("suggested", suggestion, rank: slot_hint, details: { suggestion_id: suggestion.id }) ], suggestion:)
    end

    # An agent closes its own client's suggestion.
    def withdraw(id)
      suggestion = @user.pick_suggestions.open.find_by(id:, oauth_client_id: @oauth_client_id) || raise(Update::Error, NO_LONGER_OPEN)
      suggestion.update!(status: "withdrawn", resolved_at: Time.current)
      Outcome.new(suggestion:)
    end

    def dismiss(id)
      suggestion = find_open(id) || raise(Update::Error, NO_LONGER_OPEN)
      suggestion.update!(status: "dismissed", resolved_at: Time.current)
      change = slots_for(suggestion.category).record("dismissed", suggestion, rank: suggestion.slot_hint, details: suggested_by(suggestion))
      Outcome.new(changes: [ change ], suggestion:)
    end

    # Places the suggestion in the slot the member was shown. `rank` is that slot
    # (or the one they chose to replace); `expected` is the pick they were shown in
    # it, { tool:, model: } by slug, or blank for an empty slot. Anything that no
    # longer matches fails with CHANGED and writes nothing. A field the suggestion
    # leaves blank keeps what the member has for that tool (blank for a new tool).
    def confirm(id, rank:, expected:)
      suggestion = find_open(id) || raise(Update::Error, CHANGED)
      slots = slots_for(suggestion.category)
      entries = slots.entries
      current = entries.find { |entry| entry.tool_id == suggestion.tool_id }
      raise Update::Error, CHANGED unless snapshot_matches?(suggestion, current) && (rank.nil? || current.nil? || rank == current.rank)

      target = current&.rank || rank || self.class.target_rank(suggestion, entries)
      raise Update::Error, "All three slots are taken. Choose which pick to replace." unless target
      raise Update::Error, CHANGED unless shown?(entries.find { |entry| entry.rank == target }, current, expected)

      change = slots.place(
        rank: target, tool: suggestion.tool,
        ai_model: suggestion.ai_model || current&.ai_model, context: suggestion.context || current&.context, effort: suggestion.effort || current&.effort,
        action: "confirmed", details: { suggestion_id: suggestion.id, **suggested_by(suggestion) }
      )
      suggestion.update!(status: "confirmed", resolved_at: Time.current)
      clear_outdated(suggestion, slots.entries)
      Outcome.new(changes: [ change ].compact, suggestion:)
    end

    private

    def slots_for(category, client_name: @client_name)
      Slots.new(user: @user, category:, source: @source, client_name:)
    end

    def label
      @client_name.presence || (@source == "webmcp" ? "WebMCP" : UNNAMED_AGENT)
    end

    def suggested_by(suggestion)
      { suggested_by: suggestion.client_name }
    end

    def open_in(category)
      @user.pick_suggestions.open.where(category:)
    end

    def find_open(id)
      @user.pick_suggestions.open.find_by(id:)
    end

    def close(scope, status)
      now = Time.current
      scope.update_all(status:, resolved_at: now, updated_at: now)
    end

    def expire_lapsed
      close(@user.pick_suggestions.where(status: "open").where(created_at: ...PickSuggestion::TTL.ago), "expired")
    end

    # Leaves room for one more open suggestion in the kind by superseding the oldest.
    def make_room(category)
      open = open_in(category).order(:created_at, :id).pluck(:id)
      excess = open.size - (MAX_OPEN_PER_KIND - 1)
      close(PickSuggestion.where(id: open.first(excess)), "superseded") if excess.positive?
    end

    def refuse_if_dismissed(category, tool, ai_model, context, effort)
      dismissed = @user.pick_suggestions.where(status: "dismissed", category:, tool:, ai_model:, context:, effort:, resolved_at: DISMISSAL_MEMORY.ago..).order(:resolved_at).last
      return unless dismissed

      raise Update::Error, "#{tool.name} for #{category.name.downcase} was dismissed on #{dismissed.resolved_at.to_date.to_fs(:long)}. " \
        "The member turned this exact suggestion down; do not suggest it again before #{(dismissed.resolved_at + DISMISSAL_MEMORY).to_date.to_fs(:long)}."
    end

    # The entry already has every field the suggestion names, so confirming it would
    # change nothing: a field it leaves blank keeps the entry's value.
    def same_pick?(entry, ai_model, context, effort)
      { ai_model_id: ai_model&.id, context:, effort: }.compact.all? { |field, value| entry.public_send(field) == value }
    end

    # What the suggestion was written against (nothing, or the pick it changes) is
    # still what is in the kind.
    def snapshot_matches?(suggestion, current)
      return suggestion.replaces_rank.nil? if current.nil?

      [ current.rank, current.tool_id, current.ai_model_id ] == [ suggestion.replaces_rank, suggestion.replaces_tool_id, suggestion.replaces_ai_model_id ]
    end

    # The pick in the target slot is the one the member was shown: nothing for an
    # empty slot, the suggestion's own tool for a change, else exactly `expected`.
    def shown?(occupant, current, expected)
      return occupant.nil? || occupant == current if expected.blank? || expected[:tool].blank?

      occupant.present? && occupant.tool.slug == expected[:tool].to_s && occupant.ai_model&.slug.to_s == expected[:model].to_s
    end

    # After a confirm, other open suggestions for the same tool were written against a
    # slot state that no longer exists, or now say what the pick already is.
    def clear_outdated(confirmed, entries)
      current = entries.find { |entry| entry.tool_id == confirmed.tool_id }
      outdated = open_in(confirmed.category).where(tool: confirmed.tool).reject do |other|
        snapshot_matches?(other, current) && !same_pick?(current, other.ai_model, other.context, other.effort)
      end
      close(PickSuggestion.where(id: outdated.map(&:id)), "superseded")
    end
  end
end
