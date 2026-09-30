# frozen_string_literal: true

# What the Rank editor's selects are built from, beside the member's own kinds
# (Presenter#kinds): the catalog they may pick from, the context and effort choices,
# and which kind is open.
#
#   Toolbox::PickerProps.new(user, kinds: presenter.kinds, kind: params[:kind]).to_h
#
# kinds is the member's Presenter#kinds; leave it out and they are built here.
#
# catalog   { tools: [...], models: [...] }: approved items in catalog order, then the
#           member's own items still waiting for review (marked pending), each a
#           CatalogItem#to_prop plus suggested_for, the slugs of the kinds it suits.
#           Another member's pending item is never here. A tool also carries models,
#           the slugs of the approved models it runs, its own first (Tool#paired_ai_models).
# enums     { context: Entry::CONTEXTS, effort: Entry::EFFORTS }, the only choices a slot accepts.
# selected_kind  the slug asked for, else the first kind with fewer than three confirmed
#           picks, else the first kind.
module Toolbox
  class PickerProps
    def initialize(user, kinds: nil, kind: nil)
      @user = user
      @kinds = kinds || Presenter.new(user).kinds
      @kind = kind
    end

    def to_h
      { catalog:, enums: { context: Entry::CONTEXTS, effort: Entry::EFFORTS }, selected_kind: }
    end

    private

    def catalog
      approved_models = AiModel.pickable.ordered.to_a
      tools = items(Tool).map { |tool, prop| prop.merge(models: tool.paired_ai_models(approved_models).map(&:slug)) }
      { tools:, models: items(AiModel, approved_models).map(&:last) }
    end

    # [[item, prop], ...]
    def items(klass, approved = klass.pickable.ordered.to_a)
      own = klass.pending.where(created_by: @user).order(:created_at, :id)
      (approved + own.to_a).map { |item| [ item, item.to_prop.merge(suggested_for: suggested_for(item)) ] }
    end

    def suggested_for(item)
      Array(item.category_slugs) & slugs
    end

    def selected_kind
      return @kind if slugs.include?(@kind)

      (@kinds.find { |kind| kind[:picks].size < Entry::MAX_RANK } || @kinds.first)[:category][:slug]
    end

    def slugs
      @slugs ||= @kinds.map { |kind| kind[:category][:slug] }
    end
  end
end
