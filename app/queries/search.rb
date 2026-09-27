# frozen_string_literal: true

# Home's header search: people, tools and models the viewer may see.
#
#   Search.new(viewer: Current.user, show: params[:show]).call(params[:q])
#
# Arguments
#   viewer:  a User, or nil for a visitor.
#   show:    "team" (default) or "others"; searches that population (see Audience).
#   query:   what was typed. Squished and cut to MAX_QUERY_LENGTH; under MIN_LENGTH characters
#            it finds nothing. Matching is a case-insensitive substring in which % and _ are
#            ordinary letters.
#
# call(query) returns
#   { query: the cleaned query,
#     people: [{ handle:, name: }],
#     items: [{ kind: "tool" | "model", item: Mark item, kinds: [{ category:, count: { n:, of: } }] }] }
# People are matched on name and handle only (never email) and only when they are in the
# audience: someone the viewer may not open, or who has no confirmed pick, is never found.
# Items are approved tools and models that the audience ranks somewhere; kinds lists each kind
# it is ranked in, in catalog order, with the Count from TeamRankings.item_counts. Tools come
# first, each group in the usual ranking order, and each list has at most LIMIT hits.
class Search
  MIN_LENGTH = 2
  MAX_QUERY_LENGTH = 60
  LIMIT = 10

  def initialize(viewer:, show: nil)
    @rankings = TeamRankings.new(viewer:, show:)
    @audience = @rankings.audience
  end

  def call(query)
    query = query.to_s.squish.first(MAX_QUERY_LENGTH)
    return { query:, people: [], items: [] } if query.length < MIN_LENGTH

    pattern = "%#{User.sanitize_sql_like(query)}%"
    { query:, people: people(pattern), items: items(:tool, Tool, pattern) + items(:model, AiModel, pattern) }
  end

  private

  attr_reader :rankings, :audience

  def people(pattern)
    User.where(id: audience.ids)
      .where("name LIKE :q ESCAPE '\\' OR handle LIKE :q ESCAPE '\\'", q: pattern)
      .map { |user| Audience.person(user) }
      .sort_by { |person| [ person[:name].to_s.downcase, person[:handle].to_s ] }
      .first(LIMIT)
  end

  def items(kind, klass, pattern)
    ranked = rankings.item_counts[:"#{kind}s"].keys
    found = klass.approved.where(id: ranked).where("name LIKE ? ESCAPE '\\'", pattern).index_by(&:id)

    ranked.filter_map { |id| found[id] }.first(LIMIT).map do |item|
      { kind: item.kind, item: item.to_prop, kinds: kinds_of(kind, item) }
    end
  end

  def kinds_of(kind, item)
    Category.all.filter_map do |category|
      count = rankings.count_of(kind, item.id, category:)
      { category: category.to_prop, count: } if count[:n].positive?
    end
  end
end
