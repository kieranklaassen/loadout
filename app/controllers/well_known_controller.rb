# Discovery documents MCP clients read before connecting:
# RFC 9728 protected-resource metadata (served at the root and at the RFC 9728
# path-inserted /mcp variant) and RFC 8414 authorization-server metadata.
class WellKnownController < ActionController::API
  include OauthServer

  def protected_resource
    render json: {
      resource: mcp_resource_url,
      authorization_servers: [ public_base_url ],
      scopes_supported: [ SCOPE ],
      bearer_methods_supported: [ "header" ],
      resource_name: "Loadout",
      resource_documentation: "#{public_base_url}/agents"
    }
  end

  def authorization_server
    render json: {
      issuer: public_base_url,
      authorization_endpoint: "#{public_base_url}/oauth/authorize",
      token_endpoint: "#{public_base_url}/oauth/token",
      registration_endpoint: "#{public_base_url}/oauth/register",
      revocation_endpoint: "#{public_base_url}/oauth/revoke",
      scopes_supported: [ SCOPE ],
      response_types_supported: [ "code" ],
      response_modes_supported: [ "query" ],
      grant_types_supported: %w[authorization_code refresh_token],
      token_endpoint_auth_methods_supported: [ "none" ],
      revocation_endpoint_auth_methods_supported: [ "none" ],
      code_challenge_methods_supported: [ "S256" ],
      authorization_response_iss_parameter_supported: true,
      service_documentation: "#{public_base_url}/agents"
    }
  end
end
