# frozen_string_literal: true

# Folds one catalog item into another of the same kind: a member-suggested
# "Claude-Code" into the seeded Claude Code. Entries and their history move to
# the target; an entry that would duplicate one the member already has on the
# target is dropped (keeping its go-to mark and note), then the source is deleted.
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
        User.where(id: Entry.where(column => @source.id).select(:user_id)).update_all(updated_at: Time.current)
        Entry.where(column => @source.id).find_each { |entry| repoint(entry) }
        EntryChange.where(column => @source.id).update_all(column => @target.id)
        @target.update!(category_slugs: @target.category_slugs | @source.category_slugs)
        @source.class.find(@source.id).destroy!
      end
      @target
    end

    private

    def column
      @source.is_a?(Tool) ? :tool_id : :ai_model_id
    end

    def repoint(entry)
      existing = Entry.find_by(entry.slice(:user_id, :category_id, :tool_id, :ai_model_id).merge(column => @target.id))
      return entry.update_columns(column => @target.id, updated_at: Time.current) if existing.nil?

      entry.delete
      existing.primary ||= entry.primary
      existing.note ||= entry.note
      existing.save! if existing.changed?
    end
  end
end
