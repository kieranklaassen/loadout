# frozen_string_literal: true

# Live handle availability for the claim step and settings. The page calls
# GET /handles/check?handle=… as an Inertia partial reload (only: availability,
# preserveUrl), so the answer arrives as the page's `availability` prop rather
# than through a JSON API.
class HandlesController < InertiaController
  skip_onboarding_gate

  PAGES = %w[onboarding/show settings/show].freeze

  # The answer reveals which handles are taken, private members included, so it is
  # limited per address. A limited answer is still a page answer: the field shows it.
  RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new
  rate_limit to: 60, within: 1.minute, store: RATE_LIMIT_STORE,
             with: -> { answer({ handle: User.normalize_value_for(:handle, params[:handle]).to_s, available: false, message: "Too many checks. Try again in a minute." }, status: :too_many_requests) }

  def check
    answer(User.handle_availability(params[:handle], except: Current.user))
  end

  private

  def answer(availability, status: :ok)
    component = request.headers["X-Inertia-Partial-Component"]
    return redirect_to(Current.user.onboarded? ? settings_path : welcome_path) unless request.inertia? && PAGES.include?(component)

    render inertia: component, props: { availability: }, status:
  end
end
