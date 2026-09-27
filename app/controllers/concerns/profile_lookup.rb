# Finds the profile at /:handle for the current viewer. A private profile is
# visible only to its owner; everyone else gets the same 404 as an unknown handle.
module ProfileLookup
  extend ActiveSupport::Concern

  private

  def find_profile!(visible_to_owner: true)
    user = User.find_by!(handle: params[:handle])
    return user if user.public?
    return user if visible_to_owner && owner?(user)

    raise ActiveRecord::RecordNotFound
  end

  def owner?(user)
    authenticated?.present? && Current.user == user
  end

  def public_base_url
    Rails.configuration.x.public_base_url || request.base_url
  end

  # "loadout.every.to", as printed on the page and the card.
  def public_host
    public_base_url.sub(%r{\Ahttps?://}, "")
  end
end
