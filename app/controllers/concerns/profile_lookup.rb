# Finds the profile at /:handle for the current viewer. A page the viewer may not
# open gets the same 404 as an unknown handle, so a handle never reveals who exists.
module ProfileLookup
  extend ActiveSupport::Concern

  private

  # With visible_to_owner: false the viewer is treated as a signed-out visitor, even
  # for the owner (the share card is public or nothing).
  def find_profile!(visible_to_owner: true)
    user = User.find_by!(handle: params[:handle])
    viewer = Current.user if visible_to_owner && authenticated?
    raise ActiveRecord::RecordNotFound unless user.visible_to?(viewer)

    user
  end

  def public_base_url
    ToolboxHost.base_url(request)
  end
end
