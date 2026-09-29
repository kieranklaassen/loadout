# frozen_string_literal: true

# Catalog review: approve, rename, hide, or merge the tools and models members
# add while picking. The route is behind an admin-only constraint; the guard
# here is a second lock so the controller is never reachable without it.
module Admin
  class CatalogItemsController < InertiaController
    KINDS = { "tool" => Tool, "model" => AiModel }.freeze
    STATUS_FILTERS = %w[all pending approved hidden].freeze
    KIND_FILTERS = %w[all tool model].freeze
    # Editing any of these hands the item to the admin: Catalog::Sync stops refreshing it.
    ADMIN_OWNED_FIELDS = %w[name maker released_on vibe_check_url].freeze

    before_action :require_admin
    before_action :set_item, only: %i[update destroy merge]

    def index
      render inertia: "admin/catalog", props: {
        pending: KINDS.flat_map { |kind, klass| klass.pending.order(created_at: :desc).includes(:created_by).map { |item| item_prop(item, kind) } },
        items: filtered_items,
        filters: { kind: kind_filter, status: status_filter, q: params[:q].to_s },
        counts: CatalogItem::STATUSES.index_with { |status| KINDS.values.sum { |klass| klass.where(status:).count } },
        merge_targets: KINDS.transform_values { |klass| klass.approved.ordered.map { |item| { id: item.id, name: item.name } } }
      }
    end

    def update
      @item.assign_attributes(item_params)
      @item.admin_edited_at = Time.current if (@item.changed & ADMIN_OWNED_FIELDS).any?
      if @item.save
        redirect_back_or_to admin_catalog_items_path, notice: "#{@item.name} #{update_verb}."
      else
        redirect_back_or_to admin_catalog_items_path, inertia: { errors: @item.errors.to_hash(true).transform_values(&:to_sentence) }
      end
    end

    def destroy
      @item.destroy!
      redirect_back_or_to admin_catalog_items_path, notice: "#{@item.name} deleted."
    rescue ActiveRecord::DeleteRestrictionError
      redirect_back_or_to admin_catalog_items_path, alert: "#{@item.name} is on someone's toolbox. Hide or merge it instead."
    end

    def merge
      target = @item.class.find(params.expect(:target_id))
      Catalog::Merge.call(source: @item, target:)
      redirect_back_or_to admin_catalog_items_path, notice: "Merged #{@item.name} into #{target.name}."
    rescue Catalog::Merge::Error => e
      redirect_back_or_to admin_catalog_items_path, alert: e.message
    end

    private

    def require_admin
      head :not_found unless Current.user&.admin?
    end

    def set_item
      klass = KINDS[params[:kind]] or raise ActiveRecord::RecordNotFound
      @item = klass.find(params[:id])
    end

    def item_params
      fields = %i[name maker status]
      fields += %i[released_on vibe_check_url] if @item.is_a?(AiModel)
      params.expect(item: fields)
    end

    def update_verb
      case @item.status
      when "hidden" then "is hidden from pickers"
      when "approved" then @item.saved_change_to_status? ? "approved" : "saved"
      else "saved"
      end
    end

    def kind_filter
      KIND_FILTERS.include?(params[:kind]) ? params[:kind] : "all"
    end

    def status_filter
      STATUS_FILTERS.include?(params[:status]) ? params[:status] : "all"
    end

    def filtered_items
      kinds = kind_filter == "all" ? KINDS : KINDS.slice(kind_filter)
      kinds.flat_map do |kind, klass|
        scope = klass.ordered.includes(:created_by)
        scope = scope.where(status: status_filter) unless status_filter == "all"
        scope = scope.where("lower(name) LIKE :q OR slug LIKE :q", q: "%#{klass.sanitize_sql_like(params[:q].to_s.downcase)}%") if params[:q].present?
        scope.map { |item| item_prop(item, kind) }
      end
    end

    # No usage counts, and the creator only while the item waits for review: an admin
    # sees who added a pending item, never who uses an approved one.
    def item_prop(item, kind)
      item.to_prop.merge(
        id: item.id,
        kind:,
        status: item.status,
        family: item.try(:family),
        created_by: item.pending? && item.created_by ? { name: item.created_by.display_name, handle: item.created_by.handle } : nil,
        created_at: item.created_at.iso8601
      ).merge(launch_props(item))
    end

    def launch_props(item)
      return {} unless item.is_a?(AiModel)

      { released_on: item.released_on&.iso8601, vibe_check_url: item.vibe_check_url }
    end
  end
end
