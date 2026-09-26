# frozen_string_literal: true

# Demo landing page proving the Inertia round trip: a Rails controller renders a
# snake_case page identifier and passes props the React component reads directly.
class HomeController < InertiaController
  # The demo landing page is public; every other Inertia page is gated by default.
  allow_unauthenticated_access only: :index

  def index
    render inertia: "home/index", props: { name: "Compound Stack" }
  end
end
