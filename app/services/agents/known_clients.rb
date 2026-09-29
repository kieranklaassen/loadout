# frozen_string_literal: true

# The MCP clients that earn a real mark on the consent screen and the Agents page (KTD18).
# Anyone can register a client under any name, so a name proves nothing; the redirect URI
# says where the sign-in code goes, and only an https redirect on a host that belongs to
# the product can prove that. Loopback and private-use-scheme redirects (Claude Code,
# Cursor and Codex on a laptop) prove nothing and always get an initial and the host.
#
# Keys are the Agents page's product cards (claude, claude_code, cursor, codex); `mark` is
# the file in app/frontend/assets/marks. Add a client only with an https host you know it
# uses: a host that is only plausible would hand a stranger a trusted mark.
module Agents
  module KnownClients
    CLIENTS = {
      "claude" => { mark: "claude", hosts: %w[claude.ai claude.com] }
    }.freeze

    module_function

    # The card key for a redirect URI whose scheme is https and whose lowercased host is
    # exactly an entry; nil for everything else.
    def key_for(redirect_uri)
      uri = URI.parse(redirect_uri.to_s)
      return unless uri.scheme == "https" && uri.host

      CLIENTS.find { |_key, client| client[:hosts].include?(uri.host.downcase) }&.first
    rescue URI::InvalidURIError
      nil
    end

    def mark_for(key)
      CLIENTS.dig(key, :mark)
    end
  end
end
