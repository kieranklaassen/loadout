# frozen_string_literal: true

require "omniauth-oauth2"

module OmniAuth
  module Strategies
    # Sign in with Every (every.to), ported from Baby Agent's legacy mode: a
    # plain authorization-code flow with scope basic_profile, identity read from
    # the UserInfo endpoint.
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
      SCOPE = "basic_profile"

      option :name, "every"
      option :site, nil
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
        ::OAuth2::Client.new(setting(:client_id), setting(:client_secret), deep_symbolize(options.client_options).merge(site: setting(:site)))
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
        super.merge(scope: SCOPE)
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
        cookie = request.cookies[STATE_COOKIE].to_s
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
