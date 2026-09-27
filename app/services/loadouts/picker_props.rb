# frozen_string_literal: true

# What the Rank editor's selects are built from, beside the member's own kinds
# (Presenter#kinds): the catalog they may pick from, the context and effort choices,
# and which kind is open.
#
#   Loadouts::PickerProps.new(user, kinds: presenter.kinds, kind: params[:kind]).to_h
#
# kinds is the member's Presenter#kinds; leave it out and they are built here.
#
# catalog   { tools: [...], models: [...] }: approved items in catalog order, then the
#           member's own items still waiting for review (marked pending), each a
#           CatalogItem#to_prop plus suggested_for, the slugs of the kinds it suits.
#           Another member's pending item is never here.
# enums     { context: Entry::CONTEXTS, effort: Entry::EFFORTS }, the only choices a slot accepts.
# selected_kind  the slug asked for, else the first kind with fewer than three confirmed
#           picks, else the first kind.
module Loadouts
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
      { tools: items(Tool), models: items(AiModel) }
    end

    def items(klass)
      own = klass.pending.where(created_by: @user).order(:created_at, :id)
      (klass.pickable.ordered.to_a + own.to_a).map { |item| item.to_prop.merge(suggested_for: suggested_for(item)) }
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
