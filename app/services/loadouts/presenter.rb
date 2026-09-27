# frozen_string_literal: true

# A member's current loadout as plain data, grouped by category in catalog
# order with the go-to pick first. Pages, the OG card, and agent tools all read
# this one shape.
module Loadouts
  class Presenter
    def initialize(user)
      @user = user
    end

    # [{ slug:, name:, blurb:, entries: [Entry#to_prop, ...] }, ...] for categories with entries.
    def categories(include_empty: false)
      grouped = entries.group_by(&:category_id)
      Category.all.filter_map do |category|
        picks = grouped.fetch(category.id, [])
        next if picks.empty? && !include_empty

        category.to_prop.merge(entries: picks.map(&:to_prop))
      end
    end

    def recent_changes(limit: 12)
      changes = @user.entry_changes.recent_first.includes(:category, :tool, :ai_model).limit(limit * 3)
      EntryChange.story(changes).first(limit)
    end

    def entries
      @entries ||= @user.entries.includes(:category, :tool, :ai_model).order(primary: :desc, created_at: :asc).to_a
    end

    # The go-to pick per category, for summaries and the share card.
    def top_picks
      categories.map { |category| category.merge(entries: category[:entries].first(1)) }
    end
  end
end
