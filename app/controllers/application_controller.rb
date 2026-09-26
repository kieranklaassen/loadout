class ApplicationController < ActionController::Base
  # Authentication is included on InertiaController (the base for every page),
  # not here — so framework endpoints like rails/health (/up) stay public while
  # every Inertia page is gated by default.
  #
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
end
