# "Connected agents": the MCP clients a member approved, with a revoke per
# client, plus copy-ready setup for connecting a new one.
class AgentsController < InertiaController
  include OauthServer

  SUGGESTED_PROMPT = "Suggest picks for my Loadout from what you know about how I work. Ask me before you guess, and I'll confirm them on the site.".freeze

  def index
    render inertia: "agents/index", props: {
      agents: connected_agents,
      capabilities: Agents::Capabilities.to_prop,
      mcp_url: mcp_resource_url,
      cursor_install_url: cursor_install_url,
      suggested_prompt: SUGGESTED_PROMPT
    }
  end

  # Revokes every grant the member gave this client, so its next call is a 401
  # and reconnecting means signing in and approving again. Its open suggestions
  # are withdrawn with it. Goes back to the page the member clicked Revoke on (this one, or
  # Settings).
  def destroy
    client = OauthClient.find_by!(client_id: params[:id])
    grants = Current.user.oauth_grants.where(oauth_client: client, revoked_at: nil)
    revoked = grants.update_all(revoked_at: Time.current, updated_at: Time.current)
    Current.user.oauth_authorization_codes.where(oauth_client: client, used_at: nil).delete_all
    Loadouts::Suggestions.withdraw_for_client(user: Current.user, oauth_client: client)

    redirect_back_or_to agents_path, status: :see_other, notice: revoked.positive? ? "Disconnected #{client.client_name}." : "#{client.client_name} was already disconnected."
  end

  private
    # One entry per client. `redirect_host` and `known_key` come from where the newest grant's
    # sign-in code was sent, not from what the client registered: only an https redirect on
    # an Agents::KnownClients host earns a product card. `open_suggestions` is what revoking withdraws.
    def connected_agents
      open_suggestions = Current.user.pick_suggestions.open.group(:oauth_client_id).count
      Current.user.oauth_grants.active.includes(:oauth_client, :oauth_authorization_codes).group_by(&:oauth_client).map do |client, grants|
        redirect_uri = grants.flat_map(&:oauth_authorization_codes).max_by(&:created_at)&.redirect_uri || client.redirect_uris.first
        {
          id: client.client_id,
          name: client.client_name,
          redirect_host: OauthClient.redirect_host(redirect_uri),
          known_key: Agents::KnownClients.key_for(redirect_uri),
          open_suggestions: open_suggestions.fetch(client.id, 0),
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
