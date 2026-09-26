# frozen_string_literal: true

# The front door. Signed-out visitors get the landing page; members go straight
# to their profile (or finish onboarding first).
class HomeController < InertiaController
  allow_unauthenticated_access only: :index

  def index
    if authenticated?
      return redirect_to "/welcome" unless Current.user.onboarded?
      return redirect_to "/#{Current.user.handle}"
    end

    render inertia: "home/index"
  end
end
