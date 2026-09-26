# frozen_string_literal: true

# The share card at /:handle/og.png, for link unfurls. Public profiles only:
# a private profile's card is a 404 even for its owner, so it never leaks
# through a cached unfurl.
class ProfileCardsController < InertiaController
  include ProfileLookup

  allow_unauthenticated_access only: :show

  def show
    user = find_profile!(visible_to_owner: false)
    png = ProfileCard.new(user, host: public_host).to_png

    expires_in 5.minutes, public: true
    send_data png, type: "image/png", disposition: "inline", filename: "#{user.handle}.png"
  end
end
