# RFC 7009 token revocation. Either token revokes the whole grant. The answer
# is 200 whether or not the token was known, so it reveals nothing.
class Oauth::RevocationsController < ActionController::API
  include OauthServer

  RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new
  rate_limit to: 60, within: 1.minute, store: RATE_LIMIT_STORE,
             with: -> { render_oauth_error("slow_down", "Too many requests. Try again in a minute.", status: :too_many_requests) }

  def create
    token = string_param(:token)
    return render_oauth_error("invalid_request", "token is required.") unless token

    grant = find_grant(token)
    grant.revoke! if grant && (string_param(:client_id).nil? || grant.oauth_client.client_id == string_param(:client_id))

    response.headers["Cache-Control"] = "no-store"
    head :ok
  end

  private
    def find_grant(token)
      digest = OauthToken.digest(token)
      order = params[:token_type_hint] == "refresh_token" ? %i[refresh_digest access_digest] : %i[access_digest refresh_digest]
      order.lazy.filter_map { |column| OauthGrant.find_by(column => digest) }.first
    end
end
