# frozen_string_literal: true

class SearchCatalogTool < ApplicationTool
  LIMIT = 20

  tool_name "search_catalog"
  description <<~TEXT.squish
    Searches Toolbox's catalog of approved AI tools (apps like Cursor, Claude Code, ChatGPT,
    Runway) and models (like Claude Opus 5.5 or GPT-6 Astra) by name, slug, or maker.
    Pass `category` (a slug from list_categories) to rank the items usually used for that
    kind of work first, or pass only `category` to browse its suggestions. Pass `tool` (a
    tool slug) to list the models that tool runs, its own first: suggest_picks refuses any
    other catalog model for it. Returns `{ tools: [...], models: [...] }`, each item with
    `slug`, `name`, `maker`, and `categories` (the categories it is suggested for). Prefer
    these slugs in suggest_picks so picks match the catalog exactly; a name that is not in
    the catalog becomes a new item flagged for review. #{DATA_NOTICE}
  TEXT
  input_schema(
    properties: {
      query: { type: "string", maxLength: 100, description: "Part of a tool or model name, slug, or maker, e.g. \"opus\" or \"anthropic\"." },
      category: { type: "string", maxLength: 60, description: "A category slug from list_categories, e.g. \"coding\"." },
      tool: { type: "string", maxLength: 60, description: "A tool slug, e.g. \"veo\": returns that tool and only the models it runs." }
    },
    required: [],
    additionalProperties: false
  )
  annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false)

  def call
    query = arguments[:query].to_s.squish
    category = find_category
    tool = find_tool
    raise Error, "Pass a query, a category, a tool, or any of them together." if query.blank? && category.nil? && tool.nil?
    return paired(tool, query, category) if tool

    { tools: search(Tool.approved.ordered.to_a, query, category), models: search(AiModel.approved.ordered.to_a, query, category) }
  end

  private
    def find_tool
      return if arguments[:tool].blank?

      Tool.approved.find_by_name_or_slug(arguments[:tool]) || raise(Error, "Unknown tool #{arguments[:tool].to_s.inspect}. Search for it with query first.")
    end

    # A tool the catalog pairs with no approved model says so, and the search runs over every model.
    def paired(tool, query, category)
      paired = tool.paired_ai_models
      models = paired.presence || AiModel.approved.ordered.to_a
      result = { tools: [ prop(tool) ], models: search(models, query, category, browse: paired.any?) }
      result[:note] = "The catalog does not list which models #{tool.name} runs, so any model is accepted." if paired.empty?
      result
    end

    # browse: keep every item when only a category is given, instead of just its suggestions.
    def search(items, query, category, browse: false)
      items = items.select { |item| matches?(item, query.downcase) } if query.present?
      items = items.select { |item| suggested?(item, category) } if category && query.blank? && !browse
      items = items.sort_by.with_index { |item, index| [ category && suggested?(item, category) ? 0 : 1, index ] }
      items.first(LIMIT).map { |item| prop(item) }
    end

    def prop(item)
      item.to_prop.except(:pending).merge(categories: item.category_slugs)
    end

    def matches?(item, query)
      [ item.name, item.slug, item.maker ].compact.any? { |field| field.downcase.include?(query) }
    end

    def suggested?(item, category)
      Array(item.category_slugs).include?(category.slug)
    end
end
