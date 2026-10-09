# The framed attempt of silent sign-in (EverySilentSignIn): `show` is where the
# browser points its hidden frame, `create` is Every's answer to it, sent here
# by the routes when the callback's state is a framed one. Every outcome is the
# same tiny page, which says in one attribute whether the browser is signed in
# now; the page that owns the frame reads it. Nothing here redirects a person,
# writes a flash or touches the Rails session, which the page around the frame
# and a clicked sign-in may be using at the same moment.
class Sessions::SilentController < ApplicationController
  include Authentication
  include EverySilentSignIn

  allow_unauthenticated_access
  before_action { request.session_options[:skip] = true }

  def show
    return render_outcome(signed_in: true) if authenticated?
    return render_outcome(signed_in: false) unless framed_attempt_allowed?

    state = OmniAuth::Strategies::Every.new_silent_state
    cookies[OmniAuth::Strategies::Every::SILENT_STATE_COOKIE] = { value: state, path: "/", secure: true, httponly: true,
      same_site: :lax, expires: OmniAuth::Strategies::Every::SILENT_STATE_TTL.seconds.from_now }
    redirect_to authorize_url(state), allow_other_host: true
  end

  def create
    cookies.delete(OmniAuth::Strategies::Every::SILENT_STATE_COOKIE, path: "/", secure: true)
    render_outcome(signed_in: authenticated? || sign_in_from_answer)
  end

  private
    # Only the frame the browser module opened: it set the marker first, which
    # also shows that this client keeps cookies and runs script. What is
    # refused is a request the browser says is a page of its own. A browser too
    # old to send Sec-Fetch-Dest is taken at its word, and so is "empty": a
    # service worker that passes a frame's request on sends that.
    def framed_attempt_allowed?
      silent_sign_in_allowed? && cookies[TRIED_COOKIE] == ASKING &&
        [ nil, "iframe", "empty" ].include?(request.headers["Sec-Fetch-Dest"])
    end

    def authorize_url(state)
      every = Rails.configuration.x.every_oauth
      OmniAuth::Strategies::Every.silent_authorize_url(site: every.base_url, client_id: every.client_id, scope: every.scope,
        redirect_uri: ToolboxHost.base_url(request) + OmniAuth::Strategies::Every::CALLBACK_PATH, state: state)
    end

    def sign_in_from_answer
      answer = request.env[OmniAuth::Strategies::Every::SILENT_ENV] or return false
      if (error = answer["error"])
        remember_failed_answer(error)
        return false
      end
      # The person may have signed out while the frame was asking.
      return false if cookies[SIGNED_OUT_COOKIE].present?

      sign_in_from_every(request.env["omniauth.auth"]).present?
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn("every silent sign-in could not save the user: #{e.record.errors.full_messages.to_sentence}")
      remember_silent_attempt(TRIED)
      false
    end

    def remember_failed_answer(error)
      if silent_sign_in_declined?(error)
        remember_silent_attempt(DECLINED)
      else
        Rails.logger.info("every silent sign-in failed: #{error}")
        remember_silent_attempt(TRIED)
      end
    end

    def render_outcome(signed_in:)
      @outcome = signed_in ? "signed_in" : "signed_out"
      response.headers["Cache-Control"] = "no-store"
      response.headers["X-Robots-Tag"] = "noindex"
      render :done, layout: false
    end
end
