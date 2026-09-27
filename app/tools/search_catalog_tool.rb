# frozen_string_literal: true

class SearchCatalogTool < ApplicationTool
  LIMIT = 20

  tool_name "search_catalog"
  description <<~TEXT.squish
    Searches Loadout's catalog of approved AI tools (apps like Cursor, Claude Code, ChatGPT,
    Runway) and models (like Claude Opus 5.5 or GPT-6 Astra) by name, slug, or maker.
    Pass `category` (a slug from list_categories) to rank the items usually used for that
    kind of work first, or pass only `category` to browse its suggestions. Returns
    `{ tools: [...], models: [...] }`, each item with `slug`, `name`, `maker`, and
    `categories` (the categories it is suggested for). Prefer these slugs in suggest_picks
    so picks match the catalog exactly; a name that is not in the catalog becomes a new
    item flagged for review. #{DATA_NOTICE}
  TEXT
  input_schema(
    properties: {
      query: { type: "string", maxLength: 100, description: "Part of a tool or model name, slug, or maker, e.g. \"opus\" or \"anthropic\"." },
      category: { type: "string", maxLength: 60, description: "A category slug from list_categories, e.g. \"coding\"." }
    },
    required: [],
    additionalProperties: false
  )
  annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false)

  def call
    query = arguments[:query].to_s.squish
    category = find_category
    raise Error, "Pass a query, a category, or both." if query.blank? && category.nil?

    { tools: search(Tool, query, category), models: search(AiModel, query, category) }
  end

  private
    def search(klass, query, category)
      items = klass.approved.ordered.to_a
      items = items.select { |item| matches?(item, query.downcase) } if query.present?
      items = items.select { |item| suggested?(item, category) } if category && query.blank?
      items = items.sort_by.with_index { |item, index| [ category && suggested?(item, category) ? 0 : 1, index ] }
      items.first(LIMIT).map { |item| item.to_prop.except(:hue, :monogram, :pending).merge(categories: item.category_slugs) }
    end

    def matches?(item, query)
      [ item.name, item.slug, item.maker ].compact.any? { |field| field.downcase.include?(query) }
    end

    def suggested?(item, category)
      Array(item.category_slugs).include?(category.slug)
    end
end
