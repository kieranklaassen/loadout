# The OAuth 2.1 token endpoint for public clients: exchanges an authorization
# code (with its PKCE verifier) for tokens, and rotates refresh tokens. A
# replayed code or a rotated-out refresh token revokes the grant it produced.
class Oauth::TokensController < ActionController::API
  include OauthServer

  RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new
  rate_limit to: 60, within: 1.minute, store: RATE_LIMIT_STORE,
             with: -> { render_oauth_error("slow_down", "Too many token requests. Try again in a minute.", status: :too_many_requests) }

  def create
    @client = OauthClient.find_by(client_id: string_param(:client_id)) if string_param(:client_id)
    return render_oauth_error("invalid_client", "Unknown client_id. Register the client again.", status: :unauthorized) unless @client

    case params[:grant_type]
    when "authorization_code" then exchange_code
    when "refresh_token" then refresh
    else render_oauth_error("unsupported_grant_type", "grant_type must be authorization_code or refresh_token.")
    end
  end

  private
    def exchange_code
      code = OauthAuthorizationCode.find_by_code(string_param(:code))
      return invalid_grant("The authorization code is invalid.") unless code && code.oauth_client_id == @client.id

      unless code.claim!
        code.oauth_grant&.revoke!
        return invalid_grant("The authorization code was already used.")
      end

      return invalid_grant("The authorization code expired. Start the sign-in again.") if code.expired?
      return invalid_grant("redirect_uri does not match the authorization request.") unless string_param(:redirect_uri) == code.redirect_uri
      return invalid_grant("code_verifier does not match the code_challenge.") unless OauthToken.pkce_match?(string_param(:code_verifier), code.code_challenge)
      return invalid_target unless resource_matches?(code.resource)

      grant = OauthGrant.issue!(user: code.user, client: @client, resource: code.resource, scope: code.scope)
      code.update!(oauth_grant: grant)
      render_tokens(grant)
    end

    def refresh
      token = string_param(:refresh_token)
      grant = OauthGrant.find_by_refresh_token(token)

      unless grant
        OauthGrant.find_by_previous_refresh_token(token)&.revoke!
        return invalid_grant("The refresh token is invalid.")
      end
      return invalid_grant("The refresh token is invalid.") unless grant.oauth_client_id == @client.id
      return invalid_grant("The refresh token expired or was revoked. Connect again.") unless grant.refreshable?
      return invalid_target unless resource_matches?(grant.resource)

      unless grant.rotate!
        grant.revoke!
        return invalid_grant("The refresh token was already used.")
      end

      render_tokens(grant)
    end

    def resource_matches?(resource)
      requested = params[:resource]
      requested.nil? || (mcp_resource?(requested) && canonical_uri(requested) == canonical_uri(resource))
    end

    def render_tokens(grant)
      response.headers["Cache-Control"] = "no-store"
      response.headers["Pragma"] = "no-cache"
      render json: grant.token_response
    end

    def invalid_grant(description)
      render_oauth_error("invalid_grant", description)
    end

    def invalid_target
      render_oauth_error("invalid_target", "resource must be #{mcp_resource_url}.")
    end
end
