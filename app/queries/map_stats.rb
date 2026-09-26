# frozen_string_literal: true

# The Every map: what Every members use, per category, from their current
# entries. Every member counts, private profiles included; only public profiles
# are named, everyone else folds into "and N others". All counts come from a
# handful of grouped queries, whatever the number of categories or tools.
class MapStats
  def initialize(viewer: nil)
    @viewer = viewer
  end

  def summary
    {
      members: every_entries.distinct.count(:user_id),
      picks: every_entries.count,
      tools: every_entries.distinct.count(:tool_id),
      categories: every_entries.distinct.count(:category_id)
    }
  end

  # Every category in catalog order, with its top tools and models.
  def categories(tools_limit: 5, models_limit: 3)
    Category.all.map { |category| category_panel(category, tools_limit:, models_limit:) }
  end

  # One category with the full rankings.
  def category(category)
    category_panel(category, tools_limit: nil, models_limit: nil)
  end

  # Public Every members with entries in the category, with their picks there.
  def people(category)
    entries = every_entries.merge(User.publicly_visible).where(category:)
      .includes(:user, :tool, :ai_model).order(primary: :desc, created_at: :asc)
    entries.group_by(&:user).map do |user, picks|
      person(user).merge(picks: picks.map { |entry| { tool: entry.tool.to_prop, model: entry.ai_model&.to_prop, primary: entry.primary } })
    end.sort_by { |row| row[:name].downcase }
  end

  # What the viewer might try: categories they have not filled in yet, and
  # models they use where colleagues have moved to a newer one in the family.
  def discovery
    return { empty_categories: [], upgrades: [] } if @viewer.nil?

    { empty_categories:, upgrades: }
  end

  private

  def every_entries
    Entry.joins(:user).merge(User.every_members)
  end

  def colleague_entries
    @viewer ? every_entries.where.not(user_id: @viewer.id) : every_entries
  end

  def category_panel(category, tools_limit:, models_limit:)
    tools = ranked(:tool_id, category).then { |rows| tools_limit ? rows.first(tools_limit) : rows }
    models = ranked(:ai_model_id, category).then { |rows| models_limit ? rows.first(models_limit) : rows }
    {
      category: category.to_prop,
      people_count: category_people.fetch(category.id, 0),
      tools_count: ranked(:tool_id, category).size,
      models_count: ranked(:ai_model_id, category).size,
      tools: tools.map { |row| rank_prop(row, category, :tool_id) },
      models: models.map { |row| rank_prop(row, category, :ai_model_id) }
    }
  end

  def category_people
    @category_people ||= every_entries.group(:category_id).distinct.count(:user_id)
  end

  # [[item_id, people], ...] for a category, most people first, then by name.
  def ranked(column, category)
    @ranked ||= {}
    @ranked[column] ||= begin
      counts = every_entries.where.not(column => nil).group(:category_id, column).distinct.count(:user_id)
      counts.group_by { |(category_id, _), _| category_id }.transform_values do |rows|
        rows.map { |(_, item_id), people| [ item_id, people ] }
          .sort_by { |item_id, people| [ -people, items(column)[item_id]&.name.to_s.downcase ] }
      end
    end
    @ranked[column].fetch(category.id, [])
  end

  def rank_prop(row, category, column)
    item_id, count = row
    named = named_people(column).fetch([ category.id, item_id ], [])
    prop = {
      item: items(column).fetch(item_id).to_prop,
      count:,
      share: share(count, category),
      people: named,
      others_count: count - named.size,
      in_loadout: viewer_pairs(column).include?([ category.id, item_id ])
    }
    prop[:usual_model] = usual_model(category.id, item_id) if column == :tool_id
    prop
  end

  def share(count, category)
    total = category_people.fetch(category.id, 0)
    total.zero? ? 0.0 : (count.to_f / total).round(4)
  end

  def items(column)
    @items ||= {}
    @items[column] ||= begin
      klass = column == :tool_id ? Tool : AiModel
      klass.where(id: every_entries.where.not(column => nil).select(column)).index_by(&:id)
    end
  end

  # { [category_id, item_id] => [person, ...] } for public profiles only.
  def named_people(column)
    @named_people ||= {}
    @named_people[column] ||= begin
      rows = every_entries.merge(User.publicly_visible).where.not(column => nil)
        .distinct.pluck(:category_id, column, :user_id)
      users = User.where(id: rows.map(&:last).uniq).index_by(&:id)
      rows.group_by { |category_id, item_id, _| [ category_id, item_id ] }.transform_values do |group|
        group.map { |*, user_id| person(users.fetch(user_id)) }.sort_by { |row| row[:name].downcase }
      end
    end
  end

  # The model most people pair with a tool in a category, so "Add" can bring it along.
  def usual_model(category_id, tool_id)
    @usual_models ||= every_entries.where.not(ai_model_id: nil)
      .group(:category_id, :tool_id, :ai_model_id).distinct.count(:user_id)
      .group_by { |(category, tool, _), _| [ category, tool ] }
      .transform_values { |rows| rows.max_by { |(*, model_id), people| [ people, -model_id ] }.first.last }
    model_id = @usual_models[[ category_id, tool_id ]]
    model_id && items(:ai_model_id)[model_id]&.to_prop
  end

  def viewer_pairs(column)
    @viewer_pairs ||= {}
    @viewer_pairs[column] ||= @viewer ? @viewer.entries.where.not(column => nil).pluck(:category_id, column).to_set : Set.new
  end

  def person(user)
    { handle: user.handle, name: user.display_name, avatar_url: user.avatar_url }
  end

  def empty_categories
    filled = @viewer.entries.distinct.pluck(:category_id)
    rows = Category.where.not(id: filled).map do |category|
      panel = category_panel(category, tools_limit: 3, models_limit: 0)
      { category: panel[:category], people_count: panel[:people_count], tools: panel[:tools] }
    end
    rows.each_with_index.sort_by { |row, index| [ -row[:people_count], index ] }.map(&:first)
  end

  def upgrades
    mine = @viewer.entries.joins(:ai_model).where.not(ai_models: { family: [ nil, "" ] }).includes(:category, :tool, :ai_model).to_a
    return [] if mine.empty?

    family_models = AiModel.approved.where(family: mine.map { |entry| entry.ai_model.family }.uniq).to_a
    moved = colleague_entries.where(category_id: mine.map(&:category_id).uniq, ai_model_id: family_models.map(&:id))
      .group(:category_id, :ai_model_id).distinct.count(:user_id)

    mine.filter_map do |entry|
      newer = family_models.select { |model| model.family == entry.ai_model.family && model.position < entry.ai_model.position }
      target, colleagues = newer.map { |model| [ model, moved.fetch([ entry.category_id, model.id ], 0) ] }
        .select { |_, count| count.positive? }
        .max_by { |model, count| [ count, -model.position ] }
      next if target.nil?
      next if viewer_pairs(:ai_model_id).include?([ entry.category_id, target.id ])

      {
        category: entry.category.to_prop,
        tool: entry.tool.to_prop,
        from_model: entry.ai_model.to_prop,
        to_model: target.to_prop,
        colleagues_count: colleagues
      }
    end.uniq { |upgrade| [ upgrade[:category][:slug], upgrade[:tool][:slug], upgrade[:to_model][:slug] ] }
  end
end
