# frozen_string_literal: true

require "omniauth-oauth2"

module OmniAuth
  module Strategies
    # Sign in with Every (every.to), ported from Baby Agent's legacy mode: a
    # plain authorization-code flow, identity read from the UserInfo endpoint.
    #
    # Silent sign-in: /auth/every?prompt=none asks Every to answer without any
    # screen. Every honors prompt only for an openid request, so the parameter
    # is sent only when the scope includes openid. Every answers login_required
    # when the browser is not signed in there, and consent_required unless the
    # client skips the consent page or the person approved it before; the app
    # falls back to its sign-in page on those.
    #
    # The framed attempt (Sessions::SilentController) asks the same question
    # from a hidden frame on any page. Its state starts with SILENT_STATE_PREFIX
    # and is bound by its own cookie, and its callback touches nothing in the
    # session: OmniAuth keeps one state, one origin and one set of params per
    # session and deletes them at every callback, so a frame sharing them would
    # break a clicked sign-in that overlaps it. Its outcome goes to the app in
    # env[SILENT_ENV], never through on_failure.
    #
    # The state is bound to this browser twice: OmniAuth keeps it in the
    # encrypted Rails session, and the request phase also sets it in a
    # __Host- nonce cookie that the callback must echo. A callback that fails
    # either check, or arrives after TRANSACTION_TTL, is csrf_detected and
    # leaves the session untouched so another tab's live transaction survives.
    class Every < OmniAuth::Strategies::OAuth2
      TRANSACTION_KEY = "omniauth.every"
      TRANSACTION_TTL = 10 * 60
      MAX_FUTURE_ISSUED_AT = 60
      STATE_COOKIE = "__Host-every_state"
      DEFAULT_SCOPE = "openid basic_profile"
      SILENT_STATE_COOKIE = "__Host-every_silent_state"
      SILENT_STATE_PREFIX = "silent."
      SILENT_STATE_TTL = 2 * 60
      CALLBACK_PATH = "/auth/every/callback"
      SILENT_ENV = "every.silent"
      # Sign-in runs for visitors who did not ask for it, on a server with a few
      # threads, so a slow Every must not hold one for long.
      TIMEOUT = 5

      option :name, "every"
      option :callback_path, CALLBACK_PATH
      option :site, nil
      option :requested_scope, DEFAULT_SCOPE
      option :client_options, {
        authorize_url: "/oauth/authorize",
        token_url: "/oauth/token",
        auth_scheme: :request_body
      }

      uid { raw_info["user_id"].to_s }

      info do
        {
          email: raw_info["email"],
          name: raw_info["name"].to_s.strip.presence,
          image: raw_info["avatar_url"].presence
        }
      end

      extra do
        { raw_info: raw_info }
      end

      def client
        ::OAuth2::Client.new(setting(:client_id), setting(:client_secret),
          deep_symbolize(options.client_options).merge(site: setting(:site), connection_opts: { request: { open_timeout: TIMEOUT, timeout: TIMEOUT } }))
      end

      # Where the framed attempt sends its frame: the same request as a silent
      # sign-in start, with the caller's own state.
      def self.silent_authorize_url(site:, client_id:, scope:, redirect_uri:, state:)
        ::OAuth2::Client.new(client_id, nil, site: site, authorize_url: default_options.client_options.authorize_url)
          .auth_code.authorize_url(redirect_uri: redirect_uri, scope: scope, state: state, prompt: "none")
      end

      def request_phase
        return fail!(:every_oauth_unconfigured) unless configured?

        session[TRANSACTION_KEY] = { "issued_at" => Time.now.to_i }

        response = Rack::Response.new
        response.redirect(client.auth_code.authorize_url({ redirect_uri: callback_url }.merge(authorize_params)))
        response.set_cookie(STATE_COOKIE, state_cookie_attributes(session["omniauth.state"]))
        response.finish
      end

      def authorize_params
        params = super.merge(scope: requested_scope)
        params[:prompt] = "none" if silent_request?
        params
      end

      def self.new_silent_state
        SILENT_STATE_PREFIX + SecureRandom.hex(24)
      end

      # Whether a callback's state is a framed attempt's. The routes ask too,
      # to send such a callback to Sessions::SilentController.
      def self.silent_state?(state)
        state.to_s.start_with?(SILENT_STATE_PREFIX)
      end

      def self.silent_capable?(scope)
        scope.to_s.split.include?("openid")
      end

      def requested_scope
        setting(:requested_scope).presence || DEFAULT_SCOPE
      end

      # The base method moves omniauth.origin and omniauth.params out of the
      # session before the callback phase, which a framed callback must not do
      # to a click that is under way.
      def callback_call
        return super unless silent_callback?

        setup_phase
        env[SILENT_ENV] = { "error" => silent_callback_error }
        call_app!
      end

      def callback_phase
        unless state_matches? && transaction_valid?(session[TRANSACTION_KEY])
          return fail!(:csrf_detected, CallbackError.new(:csrf_detected, "CSRF detected"))
        end

        session.delete("omniauth.state")
        session.delete(TRANSACTION_KEY)
        return fail!(:csrf_detected, CallbackError.new(:csrf_detected, "State cookie missing")) unless state_cookie_matches?

        if (error = request.params["error_reason"] || request.params["error"])
          return fail!(error, CallbackError.new(request.params["error"], request.params["error_description"] || request.params["error_reason"], request.params["error_uri"]))
        end

        self.access_token = build_access_token
        env["omniauth.auth"] = auth_hash
        call_app!
      rescue ::OAuth2::Error, CallbackError => e
        fail!(:invalid_credentials, e)
      rescue ::Timeout::Error, ::Errno::ETIMEDOUT, ::OAuth2::TimeoutError, ::OAuth2::ConnectionError => e
        fail!(:timeout, e)
      rescue ::SocketError => e
        fail!(:failed_to_connect, e)
      end

      # The registered redirect_uri has no query string; the base class would
      # otherwise append the callback's own ?code=&state= to it.
      def callback_url
        full_host + callback_path
      end

      def raw_info
        @raw_info ||= access_token.get("/oauth/userinfo").parsed.tap do |info|
          raise CallbackError.new(:invalid_userinfo, "Every userinfo missing required fields") if info["user_id"].blank? || info["email"].blank?
        end
      end

      private

      def setting(key)
        value = options[key]
        value.respond_to?(:call) ? value.call : value
      end

      def configured?
        setting(:client_id).present? && setting(:client_secret).present? && setting(:site).present?
      end

      def silent_request?
        request.params["prompt"] == "none" && self.class.silent_capable?(requested_scope)
      end

      def silent_callback?
        self.class.silent_state?(request.params["state"])
      end

      # nil when the identity was read into omniauth.auth, else what went wrong,
      # named as the clicked path names it.
      def silent_callback_error
        return "csrf_detected" unless cookie_matches_state?(SILENT_STATE_COOKIE)
        if (error = request.params["error_reason"] || request.params["error"])
          return error
        end

        self.access_token = build_access_token
        env["omniauth.auth"] = auth_hash
        nil
      rescue ::OAuth2::Error, CallbackError
        "invalid_credentials"
      rescue ::Timeout::Error, ::Errno::ETIMEDOUT, ::OAuth2::TimeoutError, ::OAuth2::ConnectionError
        "timeout"
      rescue ::SocketError
        "failed_to_connect"
      rescue StandardError => e
        # Anything else (an answer that is not JSON, a TLS failure) would reach
        # on_failure through OmniAuth, which is the clicked path's handler.
        log :error, "silent callback failed: #{e.class}, #{e.message}"
        "failed"
      end

      def state_matches?
        expected = session["omniauth.state"].to_s
        actual = request.params["state"].to_s
        !actual.empty? && !expected.empty? && secure_compare(actual, expected)
      end

      def transaction_valid?(txn)
        return false unless txn.is_a?(Hash)

        age = Time.now.to_i - txn["issued_at"].to_i
        age.between?(-MAX_FUTURE_ISSUED_AT, TRANSACTION_TTL)
      end

      def state_cookie_matches?
        cookie_matches_state?(STATE_COOKIE)
      end

      def cookie_matches_state?(name)
        cookie = request.cookies[name].to_s
        !cookie.empty? && secure_compare(cookie, request.params["state"].to_s)
      end

      # __Host- mandates Secure, Path=/, and no Domain; a browser drops the
      # cookie outright otherwise, and no sibling host can plant one.
      def state_cookie_attributes(value)
        { value: value, path: "/", secure: true, httponly: true, same_site: :lax, max_age: TRANSACTION_TTL }
      end
    end
  end
end
