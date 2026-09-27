# Shared by the MCP OAuth 2.1 endpoints, the well-known metadata, and /mcp.
# Every URL the server advertises derives from one base, so the issuer, the
# resource tokens are bound to, and the metadata never disagree.
module OauthServer
  extend ActiveSupport::Concern

  SCOPE = "loadout".freeze

  private
    def public_base_url
      LoadoutHost.base_url(request)
    end

    def mcp_resource_url
      "#{public_base_url}/mcp"
    end

    def protected_resource_metadata_url
      "#{public_base_url}/.well-known/oauth-protected-resource"
    end

    # RFC 8707 audience check. Scheme and host compare case-insensitively and a
    # trailing slash is ignored; anything else must match exactly.
    def mcp_resource?(value)
      value.is_a?(String) && canonical_uri(value) == canonical_uri(mcp_resource_url)
    end

    def canonical_uri(value)
      return if value.include?("#")

      uri = URI.parse(value)
      return unless uri.is_a?(URI::HTTP) && uri.host.present? && uri.query.nil?

      "#{uri.scheme.downcase}://#{uri.host.downcase}#{":#{uri.port}" unless uri.port == uri.default_port}#{uri.path.chomp("/")}"
    rescue URI::InvalidURIError
      nil
    end

    def string_param(name)
      value = params[name]
      value if value.is_a?(String) && value.present?
    end

    # RFC 6749 §5.2 error shape, never cached.
    def render_oauth_error(error, description, status: :bad_request)
      response.headers["Cache-Control"] = "no-store"
      render json: { error:, error_description: description }, status:
    end
end
