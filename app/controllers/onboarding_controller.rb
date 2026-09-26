# frozen_string_literal: true

# First-run flow: claim a handle, pick tools per category, choose visibility.
class OnboardingController < InertiaController
  def show
    render inertia: "onboarding/show", props: {
      suggested_handle: Current.user.handle || User.suggest_handle(from: Current.user.name.presence || Current.user.email_address, except: Current.user)
    }
  end
end
