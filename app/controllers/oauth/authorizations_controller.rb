# The OAuth 2.1 authorization endpoint and consent screen. GET validates the
# request and, once the member is signed in (the sign-in returns here), shows
# the consent page. POST re-validates the same parameters from the form, then
# issues a one-time code or reports access_denied back to the client.
#
# Until the client and redirect URI check out, errors render here and never
# redirect: an unverified redirect_uri is exactly what an attacker would send.
class Oauth::AuthorizationsController < InertiaController
  include OauthServer

  CODE_CHALLENGE = /\A[A-Za-z0-9\-_]{43}\z/
  MAX_STATE_LENGTH = 1024

  allow_unauthenticated_access
  skip_onboarding_gate if respond_to?(:skip_onboarding_gate)

  before_action :load_client
  before_action :require_authentication
  before_action :validate_request
  after_action :forbid_framing

  def new
    known = Agents::KnownClients.key_for(@redirect_uri)
    render inertia: "oauth/consent", props: {
      client: { name: @client.client_name, redirect_host:, mark: Agents::KnownClients.mark_for(known), known: known.present? },
      redirect_host:,
      authorization: authorization_params,
      authenticity_token: form_authenticity_token,
      capabilities: Agents::Capabilities.to_prop
    }
  end

  def create
    return redirect_to_client(error: "access_denied", error_description: "The member declined.") unless params[:decision] == "approve"

    code = OauthAuthorizationCode.issue!(
      client: @client, user: Current.user, redirect_uri: @redirect_uri,
      code_challenge: @code_challenge, resource: @resource, scope: SCOPE
    )
    redirect_to_client(code: code.code)
  end

  private
    def load_client
      @client = OauthClient.find_by(client_id: string_param(:client_id)) if string_param(:client_id)
      return render_invalid("This app isn't registered with Loadout. Ask it to connect again.") unless @client

      @redirect_uri = string_param(:redirect_uri)
      render_invalid("This app asked to send you somewhere it never registered, so Loadout stopped here.") unless @client.redirect_uri_registered?(@redirect_uri)
    end

    def validate_request
      @state = string_param(:state)
      @code_challenge = string_param(:code_challenge)

      return reject_request(error: "unsupported_response_type", error_description: "response_type must be code.") unless params[:response_type] == "code"
      return reject_request(error: "invalid_request", error_description: "state is too long.") if @state && @state.length > MAX_STATE_LENGTH
      return reject_request(error: "invalid_request", error_description: "code_challenge_method must be S256.") unless params[:code_challenge_method] == "S256"
      return reject_request(error: "invalid_request", error_description: "A PKCE S256 code_challenge is required.") unless @code_challenge&.match?(CODE_CHALLENGE)

      if params.key?(:resource)
        return reject_request(error: "invalid_target", error_description: "resource must be #{mcp_resource_url}.") unless mcp_resource?(params[:resource])
      end
      @resource = canonical_uri(mcp_resource_url)
    end

    def authorization_params
      {
        client_id: @client.client_id, redirect_uri: @redirect_uri, response_type: "code",
        code_challenge: @code_challenge, code_challenge_method: "S256",
        state: @state, resource: string_param(:resource), scope: string_param(:scope)
      }.compact
    end

    def redirect_host
      OauthClient.redirect_host(@redirect_uri)
    end

    def redirect_to_client(**query)
      uri = URI.parse(@redirect_uri)
      pairs = URI.decode_www_form(uri.query.to_s) + query.merge(state: @state, iss: public_base_url).compact.map { |key, value| [ key.to_s, value ] }
      uri.query = URI.encode_www_form(pairs)
      redirect_to uri.to_s, allow_other_host: true, status: :found
    end

    # A malformed request never bounces the member to the client unprompted:
    # anyone can register a client, so an automatic redirect from GET would be
    # an open redirect (RFC 9700 4.11.2). Only the consent POST, which the
    # member clicked, reports errors back to the client.
    def reject_request(error:, error_description:)
      return redirect_to_client(error:, error_description:) if request.post?

      render_invalid("This app sent an invalid sign-in request (#{error}: #{error_description}) Ask it to connect again.")
    end

    def render_invalid(message)
      render inertia: "oauth/error", props: { message: }, status: :bad_request
    end

    def forbid_framing
      response.headers["X-Frame-Options"] = "DENY"
      response.headers["Content-Security-Policy"] = "frame-ancestors 'none'"
    end
end
