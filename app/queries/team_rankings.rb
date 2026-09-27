# frozen_string_literal: true

# What the audience uses, from confirmed picks: Home's "What we use" rows, the hero
# boards, the Overall top 10, the Kind page and the editor's team list. Every "N of M"
# in the app comes from here (item_counts and the Count built from its tallies), so
# Home, Kind, launches, search hits and the agent tool cannot disagree.
#
#   rankings = TeamRankings.new(viewer: Current.user, show: params[:show])
#   rankings.rows
#
# Arguments
#   viewer:    a User, or nil for a visitor.
#   show:      "team" (default) or "others"; see Audience, which decides who is counted.
#   category:  a Category record, for kind and item_counts.
#
# N is the distinct people in the population with the item at any confirmed rank, counted
# within one kind on kind surfaces and across all kinds on Overall, launches and search.
# M is Audience#size. Only approved tools and models count, and a model counts only on a
# pick that has one. Lists rank by people, then 1st picks, then name (Audience.sort_key).
# A Count is { n:, of: } and "of" is always M. With nobody counted (M = 0) rows is empty,
# hero is nil and empty_reason says why; render that, not "0 of 0".
#
# Public methods
#   audience, people_count, empty_reason
#   rows           Home "What we use": [{ category:, top_tool:, top_model:, ranked:, last_update_at:, stale: }]
#                  top_tool / top_model are nil or { item:, count:, runner_up: { item:, count: } or nil }
#   hero           nil or { boards: [{ category:, picks: [{ rank:, tool:, model: }] }], people:, picks:, last_update_at: }
#   overall        { tools: [{ item:, count: }], models: [...] }, ten each, distinct people across kinds
#   kind(category) { category:, ranked: Count of K people, tools: [listing], models: [listing], setups:, takes:, last_update_at: }
#                  listing = { item:, count:, by_rank: { 1 => [person], 2 => [...], 3 => [...] } }
#                  (JSON turns the rank keys into "1", "2", "3"); person = { handle:, name: }
#                  setups = [{ tool:, model:, context:, effort:, count: }], picks with a model only
#                  takes  = [{ model:, url: }], Vibe Check links of launched models ranked in the kind
#   team_top       the editor's team list: { "<kind slug>" => { tools: [{ item:, count:, yours_rank: }],
#                  models: [{ item:, count:, yours_rank:, launched: }] } }, five each, yours_rank is the viewer's own
#   item_counts(category: nil)   { tools: { id => Count }, models: { id => Count } } in ranking order
#   count_of(:tool | :model, id, category: nil)   the Count for one item, zero when nobody ranked it
#   mostly_in(model)             the Mark item of the tool most people use the model in; nil under two people
#
# Last update is the newest confirmed change (entry_changes set, moved, removed, confirmed,
# baseline) by a counted person in the kind, so suggestions never move it. stale is true
# from six weeks by UTC date. Items are Mark items (CatalogItem#to_prop).
class TeamRankings
  OVERALL_LIMIT = 10
  TEAM_TOP_LIMIT = 5
  HERO_BOARDS = 3
  HERO_PICKS = 3
  STALE_AFTER_DAYS = 42
  EMPTY_REASON = "nobody_shared"

  # The people who have one item and how many of them put it 1st.
  Tally = Struct.new(:item, :people, :firsts)

  attr_reader :audience

  def initialize(viewer:, show: nil)
    @audience = Audience.new(viewer:, show:)
  end

  def people_count = audience.size

  def empty_reason = (EMPTY_REASON if audience.empty?)

  def rows
    return [] if audience.empty?

    categories.map do |category|
      updated = last_updates[category.id]
      {
        category: category.to_prop,
        top_tool: leader(ranked_items(category, :tool)),
        top_model: leader(ranked_items(category, :model)),
        ranked: count(people_in(entries_in(category))),
        last_update_at: updated&.iso8601,
        stale: stale?(updated)
      }
    end
  end

  def hero
    return if audience.empty?

    busiest = categories.select { |category| entries_in(category).any? }
      .sort_by.with_index { |category, index| [ -people_in(entries_in(category)), index ] }
      .first(HERO_BOARDS)
    { boards: busiest.map { |category| board(category) }, people: audience.size, picks: all_entries.size, last_update_at: last_updates.values.max&.iso8601 }
  end

  def overall
    { tools: ranked_items(nil, :tool).first(OVERALL_LIMIT).map { |tally| standing(tally) },
      models: ranked_items(nil, :model).first(OVERALL_LIMIT).map { |tally| standing(tally) } }
  end

  def kind(category)
    entries = entries_in(category)
    models = ranked_items(category, :model)
    {
      category: category.to_prop,
      ranked: count(people_in(entries)),
      tools: ranked_items(category, :tool).map { |tally| listing(tally, entries, :tool) },
      models: models.map { |tally| listing(tally, entries, :model) },
      setups: setups(entries),
      takes: takes(models),
      last_update_at: last_updates[category.id]&.iso8601
    }
  end

  def team_top
    launched = ModelLaunches.models.map(&:id)
    mine = audience.viewer ? audience.viewer.entries.to_a : []

    categories.to_h do |category|
      own = mine.select { |entry| entry.category_id == category.id }
      tools = ranked_items(category, :tool).first(TEAM_TOP_LIMIT).map do |tally|
        standing(tally).merge(yours_rank: own.find { |entry| entry.tool_id == tally.item.id }&.rank)
      end
      models = ranked_items(category, :model).first(TEAM_TOP_LIMIT).map do |tally|
        standing(tally).merge(yours_rank: own.select { |entry| entry.ai_model_id == tally.item.id }.map(&:rank).min, launched: launched.include?(tally.item.id))
      end
      [ category.slug, { tools:, models: } ]
    end
  end

  def item_counts(category: nil)
    @item_counts ||= {}
    @item_counts[category&.id] ||= { tools: counts(ranked_items(category, :tool)), models: counts(ranked_items(category, :model)) }
  end

  def count_of(kind, id, category: nil)
    item_counts(category:)[:"#{kind}s"].fetch(id) { count(0) }
  end

  def mostly_in(model)
    using = all_entries.select { |entry| counted_model(entry)&.id == model.id }
    ranked(using, :tool).first.item.to_prop if people_in(using) >= 2
  end

  private

  # Everything comes from one query of the population's counted picks; the tallies are Ruby
  # over at most people x kinds x 3 rows, cheaper than a grouped query per question.
  def all_entries
    @all_entries ||= audience.entries.preload(:tool, :ai_model).to_a
  end

  def entries_by_category
    @entries_by_category ||= all_entries.group_by(&:category_id)
  end

  def entries_in(category)
    entries_by_category.fetch(category.id, [])
  end

  def categories
    @categories ||= Category.all.to_a
  end

  def last_updates
    @last_updates ||= EntryChange.where(user_id: audience.ids, action: EntryChange::SLOT_ACTIONS).group(:category_id).maximum(:created_at)
  end

  # The ranked tallies of one kind, or of every kind when category is nil.
  def ranked_items(category, kind)
    @ranked_items ||= {}
    @ranked_items[[ category&.id, kind ]] ||= ranked(category ? entries_in(category) : all_entries, kind)
  end

  def ranked(entries, kind)
    tallies = entries.each_with_object({}) do |entry, by_item|
      item = item_of(entry, kind) or next
      tally = by_item[item.id] ||= Tally.new(item, Set.new, 0)
      tally.people << entry.user_id
      tally.firsts += 1 if entry.rank == 1
    end
    tallies.values.sort_by { |tally| Audience.sort_key(tally.people.size, tally.firsts, tally.item.name) + [ tally.item.id ] }
  end

  def item_of(entry, kind)
    kind == :tool ? entry.tool : counted_model(entry)
  end

  def counted_model(entry)
    entry.ai_model if entry.ai_model&.approved?
  end

  def people_in(entries)
    entries.map(&:user_id).uniq.size
  end

  def count(n)
    { n:, of: audience.size }
  end

  def counts(tallies)
    tallies.to_h { |tally| [ tally.item.id, count(tally.people.size) ] }
  end

  def standing(tally)
    { item: tally.item.to_prop, count: count(tally.people.size) }
  end

  def leader(tallies)
    top, second = tallies
    standing(top).merge(runner_up: second && standing(second)) if top
  end

  def stale?(time)
    time.present? && Time.current.utc.to_date - time.utc.to_date >= STALE_AFTER_DAYS
  end

  def listing(tally, entries, kind)
    holders = entries.select { |entry| item_of(entry, kind)&.id == tally.item.id }
    by_rank = (1..Entry::MAX_RANK).index_with do |rank|
      holders.select { |entry| entry.rank == rank }.map { |entry| audience.person_ref(entry.user_id) }.sort_by { |person| [ person[:name].to_s.downcase, person[:handle].to_s ] }
    end
    standing(tally).merge(by_rank:)
  end

  # People, not picks: each person has a tool once per kind, so a group is at most one pick each.
  def setups(entries)
    groups = entries.select { |entry| counted_model(entry) }.group_by { |entry| [ entry.tool_id, entry.ai_model_id, entry.context, entry.effort ] }.values
    groups.sort_by do |group|
      pick = group.first
      Audience.sort_key(people_in(group), group.count { |entry| entry.rank == 1 }, "#{pick.tool.name} #{pick.ai_model.name}") + [ pick.context.to_s, pick.effort.to_s ]
    end.map do |group|
      pick = group.first
      { tool: pick.tool.to_prop, model: pick.ai_model.to_prop, context: pick.context, effort: pick.effort, count: count(people_in(group)) }
    end
  end

  # Link-outs only: the Vibe Check of every launched model someone ranked in the kind.
  def takes(model_tallies)
    ranked_ids = model_tallies.map { |tally| tally.item.id }
    ModelLaunches.models.select { |model| ranked_ids.include?(model.id) }.map { |model| { model: model.to_prop, url: model.vibe_check_link } }
  end

  # The team's top tools in a kind, each with the model most people pair with it there.
  def board(category)
    entries = entries_in(category)
    picks = ranked_items(category, :tool).first(HERO_PICKS).each_with_index.map do |tally, index|
      with_tool = entries.select { |entry| entry.tool_id == tally.item.id }
      { rank: index + 1, tool: tally.item.to_prop, model: ranked(with_tool, :model).first&.item&.to_prop }
    end
    { category: category.to_prop, picks: }
  end
end
