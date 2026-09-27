# frozen_string_literal: true

# The Rank editor for the signed-in member, and the web endpoints that write a
# loadout. PATCH /loadout takes slot operations (Loadouts::Update); confirming and
# dismissing an agent's suggestion are their own POST and DELETE, addressed by
# suggestion id. All of them run as source "web": the member's own decisions.
class LoadoutsController < InertiaController
  SLOT_OPERATIONS = %w[set_pick remove_pick move_pick].freeze
  OPERATION_FIELDS = %i[op category rank tool model context effort direction].freeze

  def edit
    render inertia: "loadout/edit", props: { kinds: Loadouts::Presenter.new(Current.user).kinds }
  end

  def update
    operations = operations_param
    return redirect_back_or_to edit_loadout_path, status: :see_other, notice: "Nothing to save." if operations.empty?
    return redirect_back_or_to edit_loadout_path, status: :see_other, alert: "Use one of: #{SLOT_OPERATIONS.join(", ")}." unless operations.all? { |operation| SLOT_OPERATIONS.include?(operation["op"]) }

    apply(operations, "Saved.")
  end

  def confirm
    apply([ { op: "confirm", suggestion_id: params[:id], rank: params[:rank], expected: expected_param } ], "Confirmed.")
  end

  def dismiss
    apply([ { op: "dismiss", suggestion_id: params[:id] } ], "Removed the suggestion.")
  end

  private

  def apply(operations, notice)
    result = Loadouts::Update.call(user: Current.user, operations:, source: "web")
    redirect_back_or_to edit_loadout_path, status: :see_other, notice: result.changes.any? ? notice : "Nothing changed."
  rescue Loadouts::Update::Error => e
    redirect_back_or_to edit_loadout_path, status: :see_other, alert: e.message
  end

  def operations_param
    params.permit(operations: OPERATION_FIELDS).fetch(:operations, []).map(&:to_h)
  end

  # The pick the member was shown in the slot being replaced: { tool:, model: } by slug.
  def expected_param
    params.permit(expected: %i[tool model])[:expected]&.to_h
  end
end
