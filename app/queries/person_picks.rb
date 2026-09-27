# frozen_string_literal: true

# One person's confirmed picks as a viewer may read them: the Person view on Home and the
# Profile page. Everything about who may be shown lives in Audience and User::Visibility.
#
#   PersonPicks.new(viewer: Current.user, show: params[:show]).for(user, team: true)
#
# Arguments
#   viewer:  a User, or nil for a visitor.
#   show:    "team" (default) or "others"; the class "Team uses" compares against.
#   user:    the person, from ProfileLookup or Audience#person. Someone the viewer may not
#            open comes back as nil, the same as no one.
#   team:    true adds what only Home's Person view shows: team_uses and new_in_loadout.
#            The Profile leaves it false, so both stay empty there.
#
# for(user) returns
#   { person: { handle:, name:, avatar_url: },
#     ranked_count: kinds with at least one pick,
#     kinds: [{ category:, picks: [{ rank:, tool:, model:, context:, effort: }], team_uses: nil or { tool:, model: } }],
#     new_in_loadout: [Launch] }
# kinds lists every kind in catalog order, with an empty picks for the ones not ranked, so
# "N of 11 ranked" and "Not ranked yet" come from it. Ranks are the stored ones. A colleague
# never sees a pick on a pending tool, nor a pending model (the pick shows without it); the
# owner sees both, marked pending. team_uses names, per kind, the tool and the model (Mark
# items) the audience uses most, where the person's first pick differs from them; it is nil
# where nothing differs and the model is left out when the person picked none.
# new_in_loadout is the listed launches (ModelLaunches) among the models the person picked, in
# the Launch shape. bio is not here: the Profile adds it.
class PersonPicks
  attr_reader :viewer, :show

  def initialize(viewer:, show: nil)
    @viewer = viewer
    @show = show
  end

  def for(user, team: false)
    return unless user.visible_to?(viewer)

    picks = visible_picks(user)
    kinds = categories.map do |category|
      kind_picks = picks.fetch(category.id, [])
      { category: category.to_prop, picks: kind_picks, team_uses: (team_uses(category, kind_picks) if team) }
    end

    {
      person: Audience.person(user).merge(avatar_url: user.avatar_url),
      ranked_count: kinds.count { |kind| kind[:picks].any? },
      kinds:,
      new_in_loadout: team ? new_in_loadout(kinds) : []
    }
  end

  private

  def categories
    @categories ||= Category.all.to_a
  end

  def rankings
    @rankings ||= TeamRankings.new(viewer:, show:)
  end

  # { category_id => [pick] } in rank order, with pending items left out for anyone but the owner.
  def visible_picks(user)
    owner = user == viewer
    pairs = user.entries.preload(:tool, :ai_model).order(:rank).filter_map do |entry|
      next if entry.tool.pending? && !owner

      model = entry.ai_model unless entry.ai_model&.pending? && !owner
      [ entry.category_id, { rank: entry.rank, tool: entry.tool.to_prop, model: model&.to_prop, context: entry.context, effort: entry.effort } ]
    end
    pairs.group_by(&:first).transform_values { |group| group.map(&:last) }
  end

  def team_uses(category, picks)
    first = picks.first or return
    row = rankings.rows.find { |candidate| candidate[:category][:slug] == category.slug } or return

    tool = row[:top_tool][:item] if row[:top_tool] && row[:top_tool][:item][:slug] != first[:tool][:slug]
    model = row[:top_model][:item] if first[:model] && row[:top_model] && row[:top_model][:item][:slug] != first[:model][:slug]
    { tool:, model: } if tool || model
  end

  def new_in_loadout(kinds)
    used = kinds.flat_map { |kind| kind[:picks] }.filter_map { |pick| pick.dig(:model, :slug) }
    ModelLaunches.new(viewer:, show:).list.select { |launch| used.include?(launch[:model][:slug]) }
  end
end
