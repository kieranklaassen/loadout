# frozen_string_literal: true

class ListCategoriesTool < ApplicationTool
  tool_name "list_categories"
  description <<~TEXT.squish
    Lists the kinds of work a Loadout is organized by (coding, knowledge-work, writing,
    research, classification, image, video, animation, text-to-speech, speech-to-text,
    music, other), with each category's slug, name, one-line blurb, and how many entries
    the member already has there. Use the slugs as `category` in search_catalog and
    update_loadout. Useful for walking the member through the categories they have not
    filled in yet; ask them what they use rather than guessing.
  TEXT
  input_schema(properties: {}, required: [], additionalProperties: false)
  annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false)

  def call
    counts = user.entries.group(:category_id).count
    { categories: Category.all.map { |category| category.to_prop.merge(entries_count: counts.fetch(category.id, 0)) } }
  end
end
