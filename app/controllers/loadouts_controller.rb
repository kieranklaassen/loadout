# frozen_string_literal: true

# The Rank editor for the signed-in member, and the web endpoints that write a
# loadout. PATCH /loadout takes slot operations (Loadouts::Update); confirming and
# dismissing an agent's suggestion are their own POST and DELETE, addressed by
# suggestion id. All of them run as source "web": the member's own decisions. The
# editor shows a save as it happens, on the slot, so a success carries no flash;
# only a no-op ("Nothing changed.") and a refusal (the alert) do.
class LoadoutsController < InertiaController
  SLOT_OPERATIONS = %w[set_pick remove_pick move_pick].freeze
  OPERATION_FIELDS = %i[op category rank tool model context effort direction].freeze
  ITEM_KINDS = { "tool" => Tool, "model" => AiModel }.freeze
  ITEM_NAME_LENGTH = 2..60

  def edit
    user = Current.user
    presenter = Loadouts::Presenter.new(user)
    kinds = presenter.kinds
    render inertia: "loadout/edit", props: {
      kinds:, visibility: user.visibility, team_top: presenter.team_top,
      **Loadouts::PickerProps.new(user, kinds:, kind: params[:kind]).to_h
    }
  end

  def update
    operations = operations_param
    return redirect_back_or_to edit_loadout_path, status: :see_other, notice: "Nothing to save." if operations.empty?
    return redirect_back_or_to edit_loadout_path, status: :see_other, alert: "Use one of: #{SLOT_OPERATIONS.join(", ")}." unless operations.all? { |operation| SLOT_OPERATIONS.include?(operation["op"]) }

    apply(operations)
  end

  def confirm
    apply([ { op: "confirm", suggestion_id: params[:id], rank: params[:rank], expected: expected_param } ])
  end

  def dismiss
    apply([ { op: "dismiss", suggestion_id: params[:id] } ])
  end

  # "Add a tool or model": a name the catalog lacks becomes a pending item the member can
  # pick right away and an admin reviews. It is offered, never picked.
  def add_item
    klass = ITEM_KINDS[params[:kind]]
    name = params[:name].to_s.squish
    problem = item_problem(klass, name)
    return redirect_back_or_to edit_loadout_path, status: :see_other, inertia: { errors: { name: problem } } if problem

    klass.resolve_or_suggest!(name, user: Current.user)
    redirect_back_or_to edit_loadout_path, status: :see_other
  end

  private

  def apply(operations)
    result = Loadouts::Update.call(user: Current.user, operations:, source: "web")
    redirect_back_or_to edit_loadout_path, status: :see_other, notice: ("Nothing changed." if result.changes.empty?)
  rescue Loadouts::Update::Error => e
    redirect_back_or_to edit_loadout_path, status: :see_other, alert: e.message
  end

  def item_problem(klass, name)
    return "Choose tool or model." unless klass
    return "Use #{ITEM_NAME_LENGTH.min} to #{ITEM_NAME_LENGTH.max} characters." unless ITEM_NAME_LENGTH.cover?(name.length)

    existing = klass.find_by_name_or_slug(name)
    return unless existing

    existing.approved? || existing.created_by == Current.user ? "Already in the list." : "That one is with the admins already."
  end

  def operations_param
    params.permit(operations: OPERATION_FIELDS).fetch(:operations, []).map(&:to_h)
  end

  # The pick the member was shown in the slot being replaced: { tool:, model: } by slug.
  def expected_param
    params.permit(expected: %i[tool model])[:expected]&.to_h
  end
end
