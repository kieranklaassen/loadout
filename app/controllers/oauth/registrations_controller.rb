# RFC 7591 dynamic client registration for public MCP clients. There are no
# client secrets: registration only records a name and the redirect URIs a
# later authorization request must match exactly.
class Oauth::RegistrationsController < ActionController::API
  include OauthServer

  GRANT_TYPES = %w[authorization_code refresh_token].freeze
  STRING_FIELDS = %w[client_name software_id software_version client_uri logo_uri token_endpoint_auth_method].freeze

  RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new
  rate_limit to: 20, within: 1.hour, store: RATE_LIMIT_STORE,
             with: -> { render_oauth_error("slow_down", "Too many registrations. Try again later.", status: :too_many_requests) }

  def create
    metadata = parsed_body
    return render_oauth_error("invalid_client_metadata", "Send the client metadata as a JSON object.") unless metadata

    problem = unsupported_metadata(metadata)
    return render_oauth_error("invalid_client_metadata", problem) if problem

    client = OauthClient.new(
      client_name: metadata["client_name"].presence || "Unnamed agent",
      redirect_uris: metadata["redirect_uris"],
      **metadata.slice("software_id", "software_version", "client_uri", "logo_uri").transform_keys(&:to_sym)
    )

    if client.save
      response.headers["Cache-Control"] = "no-store"
      render json: client_information(client), status: :created
    else
      error = client.errors.include?(:redirect_uris) ? "invalid_redirect_uri" : "invalid_client_metadata"
      render_oauth_error(error, client.errors.full_messages.to_sentence)
    end
  end

  private
    def parsed_body
      body = JSON.parse(request.raw_post.presence || "null", max_nesting: 10)
      body if body.is_a?(Hash)
    rescue JSON::ParserError, JSON::NestingError
      nil
    end

    def unsupported_metadata(metadata)
      not_a_string = STRING_FIELDS.find { |key| !metadata[key].nil? && !metadata[key].is_a?(String) }
      return "#{not_a_string} must be a string" if not_a_string
      return "redirect_uris is required" unless metadata["redirect_uris"].is_a?(Array)

      auth_method = metadata.fetch("token_endpoint_auth_method", "none")
      return "Only public clients are supported: token_endpoint_auth_method must be \"none\"." unless auth_method == "none"

      grant_types = metadata.fetch("grant_types", GRANT_TYPES)
      return "grant_types may only include #{GRANT_TYPES.join(" and ")}" unless grant_types.is_a?(Array) && grant_types.any? && (grant_types - GRANT_TYPES).empty?

      response_types = metadata.fetch("response_types", [ "code" ])
      "response_types may only include code" unless response_types == [ "code" ]
    end

    def client_information(client)
      {
        client_id: client.client_id,
        client_id_issued_at: client.created_at.to_i,
        client_name: client.client_name,
        redirect_uris: client.redirect_uris,
        grant_types: GRANT_TYPES,
        response_types: [ "code" ],
        token_endpoint_auth_method: "none",
        scope: SCOPE,
        software_id: client.software_id,
        software_version: client.software_version,
        client_uri: client.client_uri,
        logo_uri: client.logo_uri
      }.compact
    end
end
