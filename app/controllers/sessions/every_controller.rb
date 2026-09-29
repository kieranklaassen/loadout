# The app side of the OmniAuth `every` strategy: `create` receives a verified
# callback, `failure` every other outcome (OmniAuth.config.on_failure).
class Sessions::EveryController < InertiaController
  include EverySilentSignIn

  allow_unauthenticated_access
  skip_onboarding_gate

  FAILURE_MESSAGES = {
    "every_oauth_unconfigured" => "Sign in with Every is not configured on this server."
  }.freeze
  DEFAULT_FAILURE_MESSAGE = "Sign in with Every did not complete. Try again."

  def create
    clear_state_cookie
    auth = request.env["omniauth.auth"]
    return failure if auth.nil?

    # Every's UserInfo carries no email_verified claim today: an Every account's
    # address is the one it signs in with, so it counts as verified. An explicit
    # false is refused, and clears any earlier team status of that account.
    if auth.extra.raw_info["email_verified"] == false
      User.where(every_user_id: auth.uid).update_all(email_verified: false)
      return failure
    end

    user = User.from_every_auth!(uid: auth.uid, email: auth.info.email, name: auth.info.name, image: auth.info.image, email_verified: true)
    forget_sign_out
    start_new_session_for user
    redirect_to((user.onboarded? || agent_consent_pending?) ? after_authentication_url : "/welcome")
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn("every sign-in could not save the user: #{e.record.errors.full_messages.to_sentence}")
    redirect_to new_session_path, alert: DEFAULT_FAILURE_MESSAGE
  end

  def failure
    clear_state_cookie
    error_type = request.env["omniauth.error.type"].to_s
    return redirect_to new_session_path if silent_sign_in_declined?(error_type)

    Rails.logger.info("every sign-in failed: #{error_type}")
    redirect_to new_session_path, alert: FAILURE_MESSAGES.fetch(error_type, DEFAULT_FAILURE_MESSAGE)
  end

  private

  # An agent's OAuth consent can finish before onboarding does: the consent page skips the gate.
  def agent_consent_pending?
    URI(session[:return_to_after_authenticating].to_s).path == "/oauth/authorize"
  rescue URI::InvalidURIError
    false
  end

  def clear_state_cookie
    cookies.delete(OmniAuth::Strategies::Every::STATE_COOKIE, path: "/", secure: true)
  end
end
