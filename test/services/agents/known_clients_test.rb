require "test_helper"

class Agents::KnownClientsTest < ActiveSupport::TestCase
  CARD_KEYS = %w[claude claude_code cursor codex].freeze

  test "an https redirect on an allowlisted host earns the mark, whatever its case or path" do
    assert_equal "claude", Agents::KnownClients.key_for("https://claude.ai/api/mcp/auth_callback")
    assert_equal "claude", Agents::KnownClients.key_for("https://CLAUDE.AI/cb?x=1")
    assert_equal "claude", Agents::KnownClients.key_for("https://claude.com/api/mcp/auth_callback")
    assert_equal "claude", Agents::KnownClients.mark_for("claude")
  end

  test "nothing else earns it: other schemes, loopback, lookalike hosts, credentials and junk (KTD18)" do
    [
      "http://claude.ai/cb", "x-evil://claude.ai/cb", "cursor://claude.ai/cb", "http://127.0.0.1:33418/callback", "http://localhost:3000/cb",
      "https://claude.ai.evil.com/cb", "https://evil.com/claude.ai", "https://notclaude.ai/cb", "https://sub.claude.ai/cb",
      "https://claude.ai@evil.com/cb", "https://claude.ai./cb", "https://evil.com/cb#https://claude.ai", "claude.ai/cb", "", nil, "https://", "not a uri"
    ].each { |uri| assert_nil Agents::KnownClients.key_for(uri), uri.inspect }
  end

  test "entries are card keys with plain lowercase hosts" do
    assert_empty Agents::KnownClients::CLIENTS.keys - CARD_KEYS
    Agents::KnownClients::CLIENTS.each_value do |client|
      client[:hosts].each { |host| assert_match(/\A[a-z0-9]([a-z0-9.-]*[a-z0-9])?\z/, host) }
      assert File.exist?(Rails.root.join("app/frontend/assets/marks/#{client[:mark]}.svg")), "#{client[:mark]} has no mark file"
    end
  end
end
