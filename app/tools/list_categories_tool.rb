# frozen_string_literal: true

class ListCategoriesTool < ApplicationTool
  tool_name "list_categories"
  description <<~TEXT.squish
    Lists the kinds of work a Loadout is organized by, with each one's slug, name, one-line
    blurb, and how many confirmed picks (0 to 3) the member already has there. Use the slugs as
    `category` in search_catalog, suggest_picks and get_team_rankings. Useful for walking the
    member through the kinds they have not filled in yet; ask them what they use rather than
    guessing. #{DATA_NOTICE}
  TEXT
  input_schema(properties: {}, required: [], additionalProperties: false)
  annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false)

  def call
    counts = user.entries.group(:category_id).count
    { categories: Category.all.map { |category| category.to_prop.merge(entries_count: counts.fetch(category.id, 0)) } }
  end
end
