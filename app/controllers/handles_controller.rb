# frozen_string_literal: true

# Live handle availability for the claim step and settings. The page calls
# GET /handles/check?handle=… as an Inertia partial reload (only: availability,
# preserveUrl), so the answer arrives as the page's `availability` prop rather
# than through a JSON API.
class HandlesController < InertiaController
  skip_onboarding_gate

  PAGES = %w[onboarding/show settings/show].freeze

  def check
    component = request.headers["X-Inertia-Partial-Component"]
    return redirect_to(Current.user.onboarded? ? settings_path : welcome_path) unless request.inertia? && PAGES.include?(component)

    render inertia: component, props: { availability: User.handle_availability(params[:handle], except: Current.user) }
  end
end
