# frozen_string_literal: true

# First-run flow, one page in three steps: claim a handle, pick tools per
# category (saved through PATCH /loadout), choose visibility. Finishing lands on
# the new profile with a "you're live" moment.
class OnboardingController < InertiaController
  skip_onboarding_gate
  before_action :redirect_onboarded, only: :show

  def show
    user = Current.user
    render inertia: "onboarding/show", props: {
      step: params[:step] == "handle" || user.handle.blank? ? "handle" : "picks",
      handle: user.handle,
      suggested_handle: user.handle || User.suggest_handle(from: user.name.presence || user.email_address, except: user),
      first_name: user.name.to_s.split.first,
      every_member: user.every_member?,
      public: user.public?,
      picker: -> { Loadouts::PickerProps.new(user).to_h }
    }
  end

  def update_handle
    availability = User.handle_availability(params[:handle], except: Current.user)
    return handle_error(availability[:message]) unless availability[:available]

    Current.user.update!(handle: availability[:handle])
    redirect_to welcome_path, status: :see_other
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    handle_error("loadout.every.to/#{availability[:handle]} is taken.")
  end

  def finish
    user = Current.user
    return redirect_to welcome_path(step: "handle"), alert: "Claim a handle first." if user.handle.blank?

    user.update!(public: ActiveModel::Type::Boolean.new.cast(params[:public]) || false, onboarded_at: user.onboarded_at || Time.current)

    if params[:next] == "agents"
      redirect_to "/agents", status: :see_other, notice: "You're live. Now let your agent fill in your loadout."
    else
      redirect_to "/#{user.handle}", status: :see_other, flash: { welcome: true }
    end
  end

  private

  def redirect_onboarded
    redirect_to "/#{Current.user.handle}" if Current.user.onboarded?
  end

  def handle_error(message)
    redirect_to welcome_path(step: "handle"), status: :see_other, inertia: { errors: { handle: message } }
  end
end
