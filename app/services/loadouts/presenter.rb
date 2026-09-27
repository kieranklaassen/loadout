# frozen_string_literal: true

# A member's own loadout as plain data, built from their confirmed picks (Entry) and
# their open suggestions, for the Rank editor and the readers that still take one
# member's picks. Anything about other people goes through the shared read layer.
module Loadouts
  class Presenter
    def initialize(user)
      @user = user
    end

    # Every kind in catalog order, for the Rank editor: the confirmed picks by rank as
    # the shared PersonPicks builder shows them to their owner (pending items marked),
    # the open suggestions with the slot each would land in, and how many wait on the member.
    def kinds
      confirmed = entries.group_by { |entry| entry.category.slug }
      waiting = open_suggestions.group_by { |suggestion| suggestion.category.slug }
      PersonPicks.new(viewer: @user).for(@user)[:kinds].map do |kind|
        slug = kind[:category][:slug]
        suggestions = waiting.fetch(slug, [])
        {
          category: kind[:category],
          picks: kind[:picks],
          suggestions: suggestions.map { |suggestion| suggestion_prop(suggestion, confirmed.fetch(slug, [])) },
          to_confirm: suggestions.size
        }
      end
    end

    # What the audience uses per kind, as the member sees it (TeamRankings#team_top).
    def team_top
      TeamRankings.new(viewer: @user).team_top
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
      changes = @user.entry_changes.narrated.recent_first.includes(:category, :tool, :ai_model).limit(limit * 3)
      EntryChange.story(changes).first(limit)
    end

    def entries
      @entries ||= @user.entries.includes(:category, :tool, :ai_model).in_display_order.to_a
    end

    # The first pick per category, for summaries and the share card.
    def top_picks
      categories.map { |category| category.merge(entries: category[:entries].first(1)) }
    end

    private

    def open_suggestions
      @user.pick_suggestions.open.includes(:category, :tool, :ai_model, :replaces_tool, :replaces_ai_model).order(:created_at, :id).to_a
    end

    def suggestion_prop(suggestion, confirmed)
      {
        id: suggestion.id,
        category: suggestion.category.slug,
        tool: suggestion.tool.to_prop,
        model: suggestion.ai_model&.to_prop,
        context: suggestion.context,
        effort: suggestion.effort,
        slot_hint: suggestion.slot_hint,
        target_rank: Suggestions.target_rank(suggestion, confirmed),
        replaces: replaces_prop(suggestion),
        suggested_by: suggestion.client_name.presence || Suggestions::UNNAMED_AGENT,
        suggested_at: suggestion.created_at.iso8601
      }
    end

    def replaces_prop(suggestion)
      return unless suggestion.replaces_rank && suggestion.replaces_tool

      { rank: suggestion.replaces_rank, tool: suggestion.replaces_tool.to_prop, model: suggestion.replaces_ai_model&.to_prop }
    end
  end
end
