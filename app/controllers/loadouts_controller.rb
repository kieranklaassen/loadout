# frozen_string_literal: true

# The full loadout editor for returning members, and the one web endpoint that
# writes a loadout. PATCH /loadout takes Loadouts::Update operations, so the
# onboarding picker, the editor, and one-click adds elsewhere (the map) all
# post the same shape and land back where they came from.
class LoadoutsController < InertiaController
  PICK_FIELDS = %i[tool model note primary].freeze
  OPERATION_FIELDS = [ :op, :category, *PICK_FIELDS, { picks: PICK_FIELDS } ].freeze

  def edit
    render inertia: "loadout/edit", props: Loadouts::PickerProps.new(Current.user).to_h.merge(handle: Current.user.handle)
  end

  def update
    operations = operations_param
    return redirect_back_or_to edit_loadout_path, status: :see_other, notice: "Nothing to save." if operations.empty?

    result = Loadouts::Update.call(user: Current.user, operations:, source: "web")
    redirect_back_or_to edit_loadout_path, status: :see_other, notice: saved_message(result.changes)
  rescue Loadouts::Update::Error => e
    redirect_back_or_to edit_loadout_path, status: :see_other, alert: e.message
  end

  private

  def operations_param
    params.permit(operations: OPERATION_FIELDS).fetch(:operations, []).map(&:to_h)
  end

  def saved_message(changes)
    return "Nothing changed." if changes.empty?

    "Saved. #{changes.size} #{"change".pluralize(changes.size)} to your loadout."
  end
end
