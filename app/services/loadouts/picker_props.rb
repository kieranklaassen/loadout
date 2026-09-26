# frozen_string_literal: true

# What the web pickers (onboarding step two and /loadout/edit) need: every
# category with its suggested tools and models, the approved catalog for search,
# and the member's current picks per category.
module Loadouts
  class PickerProps
    def initialize(user)
      @user = user
    end

    def to_h
      { categories:, catalog:, picks: }
    end

    private

    def categories
      Category.all.map do |category|
        category.to_prop.merge(
          tool_slugs: suggested(tools, category),
          model_slugs: suggested(models, category)
        )
      end
    end

    def catalog
      { tools: tools.map(&:to_prop), models: models.map(&:to_prop) }
    end

    def picks
      Presenter.new(@user).entries.group_by { |entry| entry.category.slug }.transform_values do |entries|
        entries.map do |entry|
          { tool: entry.tool.to_prop, model: entry.ai_model&.to_prop, primary: entry.primary, note: entry.note }
        end
      end
    end

    def suggested(items, category)
      items.select { |item| Array(item.category_slugs).include?(category.slug) }.map(&:slug)
    end

    def tools
      @tools ||= Tool.pickable.ordered.to_a
    end

    def models
      @models ||= AiModel.pickable.ordered.to_a
    end
  end
end
