# The MCP endpoint agents connect to: stateless Streamable HTTP serving
# ToolRegistry's tools as the member who approved the agent. Every request
# carries an OAuth access token issued for this resource; anything else gets a
# 401 that points the client at the protected-resource metadata (RFC 9728 §5.1).
class McpController < ActionController::API
  include OauthServer

  RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new
  rate_limit to: 120, within: 1.minute, store: RATE_LIMIT_STORE,
             by: -> { bearer_token ? OauthToken.digest(bearer_token) : request.remote_ip },
             with: -> { render json: { error: "Too many requests. Try again in a minute." }, status: :too_many_requests }

  before_action :authenticate

  def handle
    status, headers, body = transport.handle_request(request)
    headers = headers.transform_keys(&:downcase)
    headers.except("content-type", "content-length").each { |name, value| response.headers[name] = value }
    response.headers["Cache-Control"] = "no-store"
    content = +""
    body.each { |part| content << part }
    render body: content, status:, content_type: headers["content-type"] || "application/json"
  ensure
    body.close if body.respond_to?(:close)
  end

  private
    def authenticate
      @grant = OauthGrant.authenticate(bearer_token, resource: canonical_uri(mcp_resource_url))
      return unauthorized unless @grant

      @grant.update_column(:last_used_at, Time.current)
    end

    def bearer_token
      request.authorization.to_s[/\ABearer\s+(\S+)\s*\z/i, 1]
    end

    def unauthorized
      challenge = %(Bearer resource_metadata="#{protected_resource_metadata_url}")
      challenge += %(, error="invalid_token", error_description="The access token is invalid, expired, or revoked.") if request.authorization.present?
      response.headers["WWW-Authenticate"] = challenge
      render json: { error: request.authorization.present? ? "invalid_token" : "unauthorized" }, status: :unauthorized
    end

    def transport
      base = URI.parse(public_base_url)
      MCP::Server::Transports::StreamableHTTPTransport.new(
        ToolRegistry.mcp_server(user: @grant.user, source: "mcp", client_name: @grant.oauth_client.client_name),
        stateless: true,
        enable_json_response: true,
        serve_subscriptions_listen: false,
        allowed_hosts: [ base.host ],
        allowed_origins: [ "#{base.scheme}://#{base.host}#{":#{base.port}" unless base.port == base.default_port}" ]
      )
    end
end
