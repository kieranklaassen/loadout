class SessionsController < InertiaController
  allow_unauthenticated_access only: :new
  skip_onboarding_gate

  def new
    # Signed in already, or just now by the framed attempt on this very page.
    return redirect_to after_authentication_url if authenticated?
    return start_silent_sign_in if attempt_silent_sign_in?

    render inertia: "auth/sign_in", props: { join_every_url: ToolboxHost::JOIN_EVERY_URL, dev_login_people: (dev_login_people if Rails.env.development?) }.compact
  end

  def destroy
    terminate_session
    remember_sign_out
    redirect_to root_path, status: :see_other
  end

  private

  def dev_login_people
    User.order(:email_address).limit(30).map { |user| { email: user.email_address, name: user.name } }
  end
end
