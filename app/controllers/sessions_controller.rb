class SessionsController < InertiaController
  allow_unauthenticated_access only: :new
  skip_onboarding_gate

  def new
    return redirect_to root_path if authenticated?

    render inertia: "auth/sign_in", props: { dev_login_people: (dev_login_people if Rails.env.development?) }.compact
  end

  def destroy
    terminate_session
    redirect_to root_path, status: :see_other
  end

  private

  def dev_login_people
    User.order(:email_address).limit(30).map { |user| { email: user.email_address, name: user.name } }
  end
end
