# frozen_string_literal: true

# First-run flow, one page: claim a handle and choose who sees the page, then rank
# the first tools in the editor. Abandoning it leaves a valid, empty, private
# member, and the onboarding gate sends them back here until they finish.
class OnboardingController < InertiaController
  skip_onboarding_gate
  before_action :redirect_onboarded

  PREVIEW_KINDS = 2

  def show
    user = Current.user
    render inertia: "onboarding/show", props: {
      suggested_handle: user.handle || User.suggest_handle(from: user.name.presence || user.email_address, except: user),
      name: user.display_name,
      avatar_url: user.avatar_url,
      visibility: user.visibility,
      preview_kinds: Category.limit(PREVIEW_KINDS).pluck(:name)
    }
  end

  def update
    user = Current.user
    availability = User.handle_availability(params[:handle], except: user)
    return onboarding_error(:handle, availability[:message]) unless availability[:available]

    visibility = params[:visibility].presence || user.visibility
    if user.update(handle: availability[:handle], visibility:, onboarded_at: user.onboarded_at || Time.current)
      redirect_to edit_loadout_path, status: :see_other
    else
      field = user.errors.attribute_names.first
      onboarding_error(field, user.errors.full_messages_for(field).first)
    end
  rescue ActiveRecord::RecordNotUnique
    onboarding_error(:handle, "#{LoadoutHost.host}/#{availability[:handle]} was just taken. Try another.")
  end

  private

  def redirect_onboarded
    redirect_to edit_loadout_path, status: :see_other if Current.user.onboarded?
  end

  def onboarding_error(field, message)
    redirect_to welcome_path, status: :see_other, inertia: { errors: { field => message } }
  end
end
