# frozen_string_literal: true

# Account settings: the profile link (handle), bio, visibility, and deleting the
# account. Changing the handle retires the old link immediately.
class SettingsController < InertiaController
  def show
    user = Current.user
    render inertia: "settings/show", props: {
      account: {
        handle: user.handle,
        bio: user.bio.to_s,
        public: user.public?,
        email: user.email_address,
        every_member: user.every_member?
      }
    }
  end

  def update
    user = Current.user
    attributes = params.permit(:handle, :bio, :public)

    if attributes.key?(:handle)
      availability = User.handle_availability(attributes[:handle], except: user)
      return settings_error(:handle, availability[:message]) unless availability[:available]
    end

    if user.update(attributes)
      # A profile page may ask to go public; a handle change must not return to the retired link.
      return redirect_to settings_path, status: :see_other, notice: saved_message(user) if user.saved_change_to_handle?

      redirect_back_or_to settings_path, status: :see_other, notice: saved_message(user)
    else
      field = user.errors.attribute_names.first
      settings_error(field, user.errors.full_messages_for(field).first)
    end
  rescue ActiveRecord::RecordNotUnique
    settings_error(:handle, "loadout.every.to/#{attributes[:handle]} was just taken. Try another.")
  end

  def destroy
    user = Current.user
    expected = user.handle.presence || "delete"
    return settings_error(:confirmation, "Type #{expected} to confirm.") unless params[:confirmation].to_s.strip.downcase == expected

    user.destroy!
    cookies.delete(:session_id)
    Current.session = nil
    redirect_to root_path, status: :see_other, notice: "Your account and loadout are deleted."
  end

  private

  def saved_message(user)
    if user.saved_change_to_handle?
      "Your profile now lives at loadout.every.to/#{user.handle}."
    elsif user.saved_change_to_public?
      user.public? ? "Your profile is public." : "Your profile is private."
    else
      "Saved."
    end
  end

  def settings_error(field, message)
    redirect_to settings_path, status: :see_other, inertia: { errors: { field => message } }
  end
end
