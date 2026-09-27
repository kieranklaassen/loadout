# frozen_string_literal: true

# The share card at /:handle/og.png, for link unfurls. Only "anyone with the link"
# profiles that have a confirmed pick get one; every other case is the same 404 as
# an unknown handle, even for the owner, so a card never leaks through a cached
# unfurl. The card is drawn for a visitor whoever asks, so one response fits every
# viewer. It is revalidated on every request (no-cache plus an ETag of its content)
# rather than cached for a fixed time, so narrowing visibility or editing a pick shows
# on the next fetch.
class ProfileCardsController < InertiaController
  include ProfileLookup

  allow_unauthenticated_access only: :show

  def show
    user = find_profile!(visible_to_owner: false)
    card = ProfileCard.new(user)
    raise ActiveRecord::RecordNotFound unless card.picks?

    if stale?(strong_etag: card.digest, cache_control: { no_cache: true })
      send_data card.to_png, type: "image/png", disposition: "inline", filename: "#{user.handle}.png"
    end
  end
end
