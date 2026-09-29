# Silent sign-in with Every: the sign-in page first asks Every, without any
# screen, whether this browser is already signed in there, and only renders when
# Every says no. Two markers keep it from looping or undoing a sign-out:
#
# - ATTEMPT_KEY (Rails session): one silent attempt per ATTEMPT_TTL, so Every's
#   login_required or consent_required answer lands on the rendered page.
# - SIGNED_OUT_COOKIE (permanent): set by signing out, cleared only by a
#   completed Every sign-in, so signing out of Toolbox sticks while the browser
#   stays signed in to every.to.
module EverySilentSignIn
  extend ActiveSupport::Concern

  ATTEMPT_KEY = :every_silent_attempted_at
  ATTEMPT_TTL = 10.minutes
  SIGNED_OUT_COOKIE = :every_signed_out
  SILENT_SIGN_IN_PATH = "/auth/every?prompt=none"
  # Every's answers to a prompt=none request that mean "ask the person instead".
  FALLBACK_ERRORS = %w[login_required consent_required interaction_required account_selection_required].freeze

  private
    def silent_sign_in_available?
      every = Rails.configuration.x.every_oauth
      every.client_id.present? && every.client_secret.present? && every.base_url.present? &&
        OmniAuth::Strategies::Every.silent_capable?(every.scope)
    end

    def attempt_silent_sign_in?
      return false unless silent_sign_in_available?
      return false if cookies[SIGNED_OUT_COOKIE].present? || flash[:alert].present?

      attempted_at = session[ATTEMPT_KEY].to_i
      attempted_at.zero? || Time.current.to_i - attempted_at > ATTEMPT_TTL.to_i
    end

    def start_silent_sign_in
      session[ATTEMPT_KEY] = Time.current.to_i
      redirect_to SILENT_SIGN_IN_PATH
    end

    def silent_sign_in_declined?(error_type)
      FALLBACK_ERRORS.include?(error_type)
    end

    def remember_sign_out
      cookies.permanent[SIGNED_OUT_COOKIE] = { value: "1", httponly: true, same_site: :lax, secure: request.ssl? }
    end

    def forget_sign_out
      cookies.delete(SIGNED_OUT_COOKIE)
      session.delete(ATTEMPT_KEY)
    end
end
