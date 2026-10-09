# Silent sign-in with Every: Toolbox asks Every, without any screen, whether
# this browser is already signed in there. Two paths ask:
#
# - The framed attempt (Sessions::SilentController): any page says in the
#   silent_sign_in_path prop that an attempt is due, and the browser asks from a
#   hidden frame, so a visitor never leaves the page and a client that keeps no
#   cookies or runs no script is never sent to every.to.
# - The sign-in page (SessionsController#new) asks by redirect before it
#   renders: the person asked to sign in, and it works where a frame does not.
#
# Two cookies keep both from looping or undoing a sign-out:
#
# - TRIED_COOKIE says an attempt was made and who says so. The browser sets
#   ASKING before it frames; the server sets TRIED when an attempt starts by
#   redirect or fails, and DECLINED, for a day, when Every answers that it does
#   not know this browser. Any value stops a new framed attempt. Only a
#   server-set value stops the sign-in page's attempt: ASKING alone means a
#   frame was started and nothing answered. It is not HttpOnly, because the
#   browser's script sets and reads it.
# - SIGNED_OUT_COOKIE (permanent): set by signing out, cleared only by a
#   completed Every sign-in, so signing out of Toolbox sticks while the browser
#   stays signed in to every.to.
module EverySilentSignIn
  extend ActiveSupport::Concern

  TRIED_COOKIE = :every_silent_tried
  ASKING = "asking"
  TRIED = "tried"
  DECLINED = "declined"
  ATTEMPT_TTL = 10.minutes
  DECLINE_TTL = 1.day
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

    # Whether this browser may be asked at all: never one that signed out here.
    def silent_sign_in_allowed?
      silent_sign_in_available? && cookies[SIGNED_OUT_COOKIE].blank?
    end

    # The framed attempt is due. Asking this writes nothing, so a public page
    # stays the same for a client that keeps no cookies.
    def silent_sign_in_due?
      !authenticated? && silent_sign_in_allowed? && cookies[TRIED_COOKIE].blank?
    end

    # The sign-in page's own attempt. ?silent=tried is how a failed attempt
    # comes back, and stops a second one for a client that kept no cookie.
    def attempt_silent_sign_in?
      return false unless silent_sign_in_allowed?
      return false if flash[:alert].present? || params[:silent] == TRIED

      [ TRIED, DECLINED ].exclude?(cookies[TRIED_COOKIE])
    end

    # OmniAuth answers /auth/every with a redirect to every.to, which an Inertia
    # visit cannot follow over XHR, so an Inertia request gets the location
    # response that makes the browser navigate instead.
    def start_silent_sign_in
      remember_silent_attempt(TRIED)
      return inertia_location(SILENT_SIGN_IN_PATH) if request.headers["X-Inertia"].present?

      redirect_to SILENT_SIGN_IN_PATH
    end

    def silent_sign_in_declined?(error_type)
      FALLBACK_ERRORS.include?(error_type)
    end

    def remember_silent_attempt(answer)
      lifetime = answer == DECLINED ? DECLINE_TTL : ATTEMPT_TTL
      cookies[TRIED_COOKIE] = { value: answer, expires: lifetime.from_now, same_site: :lax, secure: request.ssl? }
    end

    def remember_sign_out
      cookies.permanent[SIGNED_OUT_COOKIE] = { value: "1", httponly: true, same_site: :lax, secure: request.ssl? }
    end

    def forget_sign_out
      cookies.delete(SIGNED_OUT_COOKIE)
      cookies.delete(TRIED_COOKIE)
    end

    # Signs in the person Every vouches for and returns them, or nil.
    def sign_in_from_every(auth)
      user = user_from_every(auth) or return
      forget_sign_out
      start_new_session_for user
      user
    end

    # The person Every vouches for, created on a first sign-in, or nil when
    # Every says the address is not theirs.
    #
    # Every's UserInfo carries no email_verified claim today: an Every account's
    # address is the one it signs in with, so it counts as verified. An explicit
    # false is refused, and clears any earlier team status of that account.
    def user_from_every(auth)
      if auth.extra.raw_info["email_verified"] == false
        User.where(every_user_id: auth.uid).update_all(email_verified: false)
        return
      end

      User.from_every_auth!(uid: auth.uid, email: auth.info.email, name: auth.info.name, image: auth.info.image, email_verified: true)
    end
end
