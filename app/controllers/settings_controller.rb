# frozen_string_literal: true

# Account settings: the profile link (handle), bio, who can see the page, connected
# agents, and deleting the account. Changing the handle retires the old link
# immediately. Name comes from the Every account and is read-only.
class SettingsController < InertiaController
  def show
    user = Current.user
    render inertia: "settings/show", props: {
      account: { name: user.display_name, handle: user.handle, bio: user.bio.to_s, visibility: user.visibility },
      agents: connected_agents
    }
  end

  def update
    user = Current.user
    attributes = params.permit(:handle, :bio, :visibility)

    if attributes.key?(:handle)
      availability = User.handle_availability(attributes[:handle], except: user)
      return settings_error(:handle, availability[:message]) unless availability[:available]
    end

    if user.update(attributes)
      redirect_to settings_path, status: :see_other, notice: saved_message(user)
    else
      field = user.errors.attribute_names.first
      settings_error(field, user.errors.full_messages_for(field).first)
    end
  rescue ActiveRecord::RecordNotUnique
    settings_error(:handle, "#{ToolboxHost.host}/#{attributes[:handle]} was just taken. Try another.")
  end

  def destroy
    user = Current.user
    expected = user.handle.presence || "delete"
    return settings_error(:confirmation, "Type #{expected} to confirm.") unless params[:confirmation].to_s.strip.downcase == expected

    user.destroy!
    cookies.delete(:session_id)
    Current.session = nil
    redirect_to root_path, status: :see_other, notice: "Your account and toolbox are deleted."
  end

  private

  def saved_message(user)
    user.saved_change_to_handle? ? "Your profile now lives at #{ToolboxHost.host}/#{user.handle}." : "Saved."
  end

  def settings_error(field, message)
    redirect_to settings_path, status: :see_other, inertia: { errors: { field => message } }
  end

  # The clients the member approved, one row each, newest activity first. Revoking is
  # DELETE /agents/:id with the client id.
  def connected_agents
    Current.user.oauth_grants.connected_clients
  end
end
