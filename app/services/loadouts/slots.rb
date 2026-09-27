# frozen_string_literal: true

# Rank arithmetic for one member's picks in one kind of work, and the change rows
# that record it. A Slots instance is one batch: every row it writes shares one
# details["batch"] and one timestamp, and carries the slot as it stands after the
# change, so a swap or a removal with compaction replays as a single step (KTD7).
# Make a new instance for each operation.
#
# Ranks are unique per member and kind, and SQLite checks a unique index row by
# row, so rows that change rank are first parked PARKED above their rank and then
# given their final rank, inside the caller's transaction (KTD6).
module Loadouts
  class Slots
    PARKED = 10

    def initialize(user:, category:, source:, client_name: nil, at: Time.current)
      @user = user
      @category = category
      @source = source
      @client_name = client_name
      @at = at
      @batch = SecureRandom.uuid
    end

    # The member's picks in this kind, by rank. Read fresh: the slots change under you.
    def entries
      @user.entries.where(category: @category).includes(:tool, :ai_model).order(:rank).to_a
    end

    # Fills the slot at `rank`, or edits the pick already there. Returns the change
    # row, or nil when the slot already holds exactly this. `action` is "set", or
    # "confirmed" when the member accepts a suggestion.
    def place(rank:, tool:, ai_model: nil, context: nil, effort: nil, action: "set", details: {})
      raise Update::Error, "You can rank up to #{Entry::MAX_RANK} picks per kind." unless (1..Entry::MAX_RANK).cover?(rank)

      current = entries
      elsewhere = current.find { |entry| entry.tool_id == tool.id && entry.rank != rank }
      raise Update::Error, "#{tool.name} is already your #{elsewhere.rank.ordinalize} pick for #{kind_name}." if elsewhere

      entry = current.find { |candidate| candidate.rank == rank } || Entry.new(user: @user, category: @category, rank:)
      entry.assign_attributes(tool:, ai_model:, context:, effort:)
      return unless entry.changed?

      entry.save!
      record(action, entry, rank:, details:)
    end

    # Removes the pick at `rank` and closes the gap, so the rest stay contiguous
    # from 1. Returns the `removed` row followed by a `moved` row per pick that moved up.
    def remove(rank:)
      Entry.transaction do
        current = entries
        removed = current.find { |entry| entry.rank == rank } || raise(Update::Error, "Nothing is ranked #{rank.ordinalize} for #{kind_name}.")
        removed.destroy!
        moves = (current - [ removed ]).each_with_index.filter_map { |entry, index| [ entry, index + 1 ] if entry.rank != index + 1 }
        [ record("removed", removed, rank:), *reassign(moves) ]
      end
    end

    # Swaps the pick at `rank` with the next pick above ("up") or below ("down").
    # Returns one `moved` row for each of the two.
    def move(rank:, direction:)
      Entry.transaction do
        current = entries
        index = current.index { |entry| entry.rank == rank } || raise(Update::Error, "Nothing is ranked #{rank.ordinalize} for #{kind_name}.")
        entry = current[index]
        neighbour_index = direction == "up" ? index - 1 : index + 1
        neighbour = current[neighbour_index] if neighbour_index >= 0
        raise Update::Error, "#{entry.tool.name} is already your #{direction == "up" ? "first" : "last"} pick for #{kind_name}." unless neighbour

        reassign([ [ entry, neighbour.rank ], [ neighbour, entry.rank ] ])
      end
    end

    # One change row for a pick (an Entry, or a PickSuggestion for the rows that never
    # touch a slot). `rank` is the slot after the change; `from_rank` the slot it left.
    def record(action, pick, rank:, from_rank: nil, details: {})
      EntryChange.create!(
        user: @user, category: @category, tool: pick.tool, ai_model: pick.ai_model,
        action:, source: @source, client_name: @client_name, rank:, from_rank:,
        context: pick.context, effort: pick.effort,
        details: { batch: @batch }.merge(details), created_at: @at
      )
    end

    private

    # moves: [[entry, new_rank], ...]
    def reassign(moves)
      return [] if moves.empty?

      Entry.where(id: moves.map { |entry, _| entry.id }).update_all([ "rank = rank + ?", PARKED ])
      moves.each { |entry, rank| Entry.where(id: entry.id).update_all(rank:, updated_at: @at) }
      moves.map { |entry, rank| record("moved", entry, rank:, from_rank: entry.rank) }
    end

    def kind_name
      @category.name.downcase
    end
  end
end
