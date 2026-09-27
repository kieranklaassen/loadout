# frozen_string_literal: true

# Folds one catalog item into another of the same kind: a member-suggested
# "Claude-Code" into the seeded Claude Code. Picks, their history and suggestions
# move to the target, then the source is deleted. A member who ranked both tools in
# one kind keeps the lower rank (the higher pick); the other is removed through
# Loadouts::Slots as a system change, so ranks close up and the change rows still
# replay to the loadout. A model may repeat across a member's picks, so a model
# merge never removes one.
module Catalog
  class Merge
    class Error < StandardError; end

    def self.call(...) = new(...).call

    def initialize(source:, target:)
      @source = source
      @target = target
    end

    def call
      raise Error, "Merge into an item of the same kind." unless @source.instance_of?(@target.class)
      raise Error, "An item can't be merged into itself." if @source.id == @target.id

      ApplicationRecord.transaction do
        open_ids = PickSuggestion.open.where(column => @source.id).ids
        User.where(id: Entry.where(column => @source.id).select(:user_id)).update_all(updated_at: Time.current)
        remove_duplicate_picks if @source.is_a?(Tool)
        Entry.where(column => @source.id).update_all(column => @target.id, updated_at: Time.current)
        EntryChange.where(column => @source.id).update_all(column => @target.id)
        repoint_suggestions(open_ids)
        @target.update!(category_slugs: @target.category_slugs | @source.category_slugs)
        @source.class.find(@source.id).destroy!
      end
      @target
    end

    private

    def replaces_column
      column == :tool_id ? :replaces_tool_id : :replaces_ai_model_id
    end

    def column
      @source.is_a?(Tool) ? :tool_id : :ai_model_id
    end

    # A tool is unique per member and kind, and SQLite checks that row by row, so the
    # duplicates go before anything is repointed.
    def remove_duplicate_picks
      Entry.where(tool_id: @source.id).includes(:user, :category).find_each do |entry|
        twin = Entry.find_by(entry.slice(:user_id, :category_id).merge(tool_id: @target.id))
        next unless twin

        Loadouts::Slots.new(user: entry.user, category: entry.category, source: "system").remove(rank: [ entry.rank, twin.rank ].max)
      end
    end

    # All statuses move: the dismissed ones are what the member was once shown. An
    # open one that now proposes exactly the pick the member already has is done.
    def repoint_suggestions(open_ids)
      PickSuggestion.where(column => @source.id).update_all(column => @target.id)
      PickSuggestion.where(replaces_column => @source.id).update_all(replaces_column => @target.id)

      now = Time.current
      PickSuggestion.where(id: open_ids).find_each do |suggestion|
        pick = Entry.find_by(user_id: suggestion.user_id, category_id: suggestion.category_id, tool_id: suggestion.tool_id)
        next unless pick && [ pick.ai_model_id, pick.context, pick.effort ] == [ suggestion.ai_model_id, suggestion.context, suggestion.effort ]

        suggestion.update_columns(status: "superseded", resolved_at: now, updated_at: now)
      end
    end
  end
end
