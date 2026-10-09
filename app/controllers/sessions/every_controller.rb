# The app side of the OmniAuth `every` strategy: `create` receives a verified
# callback, `failure` every other outcome (OmniAuth.config.on_failure).
class Sessions::EveryController < InertiaController
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

    user = sign_in_from_every(auth) or return failure
    redirect_to((user.onboarded? || agent_consent_pending?) ? after_authentication_url : "/welcome")
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn("every sign-in could not save the user: #{e.record.errors.full_messages.to_sentence}")
    redirect_to sign_in_page, alert: DEFAULT_FAILURE_MESSAGE
  end

  # A silent attempt the person did not start fails without a word.
  def failure
    clear_state_cookie
    error_type = request.env["omniauth.error.type"].to_s
    if silent_sign_in_declined?(error_type)
      remember_silent_attempt(DECLINED)
      return redirect_to sign_in_page
    end

    Rails.logger.info("every sign-in failed: #{error_type}")
    return redirect_to sign_in_page if silent_attempt?

    redirect_to sign_in_page, alert: FAILURE_MESSAGES.fetch(error_type, DEFAULT_FAILURE_MESSAGE)
  end

  private

  # An agent's OAuth consent can finish before onboarding does: the consent page skips the gate.
  def agent_consent_pending?
    URI(session[:return_to_after_authenticating].to_s).path == "/oauth/authorize"
  rescue URI::InvalidURIError
    false
  end

  def silent_attempt?
    request.env["omniauth.params"].to_h["prompt"] == "none"
  end

  # The sign-in page, told not to ask Every silently again. A client that keeps
  # no cookies comes back from a silent attempt with nothing else to say so.
  def sign_in_page
    new_session_path(silent: TRIED)
  end

  def clear_state_cookie
    cookies.delete(OmniAuth::Strategies::Every::STATE_COOKIE, path: "/", secure: true)
  end
end
