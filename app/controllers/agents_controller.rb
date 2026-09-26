# "Connected agents": the MCP clients a member approved, with a revoke per
# client, plus copy-ready setup for connecting a new one.
class AgentsController < InertiaController
  include OauthServer

  SUGGESTED_PROMPT = "Fill in my Loadout from what you know about how I work. Ask me before you guess.".freeze

  def index
    render inertia: "agents/index", props: {
      agents: connected_agents,
      mcp_url: mcp_resource_url,
      cursor_install_url: cursor_install_url,
      suggested_prompt: SUGGESTED_PROMPT
    }
  end

  # Revokes every grant the member gave this client, so its next call is a 401
  # and reconnecting means signing in and approving again.
  def destroy
    client = OauthClient.find_by!(client_id: params[:id])
    grants = Current.user.oauth_grants.where(oauth_client: client, revoked_at: nil)
    revoked = grants.update_all(revoked_at: Time.current, updated_at: Time.current)
    Current.user.oauth_authorization_codes.where(oauth_client: client, used_at: nil).delete_all

    redirect_to agents_path, notice: revoked.positive? ? "Disconnected #{client.client_name}." : "#{client.client_name} was already disconnected."
  end

  private
    def connected_agents
      Current.user.oauth_grants.active.includes(:oauth_client).group_by(&:oauth_client).map do |client, grants|
        {
          id: client.client_id,
          name: client.client_name,
          hue: Tool.hue_for(client.client_name),
          monogram: Tool.monogram_for(client.client_name),
          connected_at: grants.map(&:created_at).min.iso8601,
          last_used_at: grants.filter_map(&:last_used_at).max&.iso8601
        }
      end.sort_by { |agent| agent[:last_used_at] || agent[:connected_at] }.reverse
    end

    def cursor_install_url
      config = Base64.strict_encode64({ url: mcp_resource_url }.to_json)
      "cursor://anysphere.cursor-deeplink/mcp/install?#{URI.encode_www_form(name: "loadout", config:)}"
    end
end
