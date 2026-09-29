# Demo data for local development and screenshots. Dev login lists these members.
#
# Everything here is DEMO data: made-up people, picks, launch dates and Vibe Check
# links. None of it is real launch data, and none of it belongs in a real database.
# Real release dates and links are set by an admin in /admin/catalog_items.

# Each pick is [ tool, model, context, effort ] by slug; a pick's place in its list is its rank.
DEMO_MEMBERS = [
  { name: "Kieran Klaassen", email: "kieran@every.to", handle: "kieran", visibility: "link", bio: "GM of Cora. Building with agents all day.",
    picks: {
      "coding" => [ %w[claude-code claude-opus-5-5 1m high], %w[cursor claude-opus-5-5 200k medium], %w[codex gpt-6-astra 200k low] ],
      "knowledge-work" => [ %w[claude claude-opus-5-5 1m], [ "cora" ] ],
      "classification" => [ %w[typesafe-jev jev] ],
      "speech-to-text" => [ [ "monologue" ] ],
      "video" => [ %w[runway runway-gen-4-5] ]
    } },
  { name: "Dan Shipper", email: "dan@every.to", handle: "dan", visibility: "link", bio: "CEO of Every.",
    picks: {
      "writing" => [ %w[claude claude-fable-5-1], [ "spiral" ] ],
      "knowledge-work" => [ %w[chatgpt gpt-6-astra 200k medium], %w[claude claude-opus-5-5 1m high] ],
      "coding" => [ %w[claude-code claude-opus-5-5 1m high] ],
      "research" => [ %w[chatgpt gpt-6-astra] ]
    } },
  { name: "Katie Parrott", email: "katie@every.to", handle: "katie", visibility: "team",
    picks: {
      "writing" => [ %w[claude claude-fable-5-1] ],
      "image" => [ %w[midjourney midjourney-v8], %w[chatgpt-images gpt-image-2] ],
      "research" => [ [ "perplexity" ] ]
    } },
  { name: "Naveen Naidu", email: "naveen@every.to", handle: "naveen", visibility: "only_me",
    picks: {
      "coding" => [ %w[cursor composer-2-5 200k high], %w[claude-code claude-opus-5 1m medium] ],
      "classification" => [ %w[openai-api gpt-5-6-mini] ]
    } },
  { name: "Lucas Crespo", email: "lucas@every.to", handle: "lucas", visibility: "team", bio: "Designing Every.",
    picks: {
      "image" => [ %w[midjourney midjourney-v8], %w[figma-weave nano-banana-2] ],
      "video" => [ %w[veo veo-4], %w[runway runway-gen-4-5] ],
      "animation" => [ [ "jitter" ], %w[kling kling-3] ]
    } },
  { name: "Brandon Gell", email: "brandon@every.to", handle: "brandon", visibility: "link",
    picks: {
      "knowledge-work" => [ %w[claude claude-opus-5-5 1m low], [ "granola" ] ],
      "text-to-speech" => [ %w[elevenlabs eleven-v3] ]
    } }
].freeze

# DEMO launch rows for Home: [ model slug, days since release ]. Links point at a demo path on the allowed host.
DEMO_LAUNCHES = [ [ "claude-opus-5-5", 9 ], [ "gpt-6-astra", 23 ], [ "veo-4", 40 ] ].freeze

DEMO_MEMBERS.each do |member|
  user = User.find_or_initialize_by(email_address: member[:email])
  user.update!(name: member[:name], handle: member[:handle], visibility: member[:visibility], bio: member[:bio],
    email_verified: true, onboarded_at: user.onboarded_at || Time.current)
  next if user.entries.exists?

  operations = member[:picks].flat_map do |category, picks|
    picks.each_with_index.map do |(tool, model, context, effort), index|
      { op: "set_pick", category:, rank: index + 1, tool:, model:, context:, effort: }
    end
  end
  Toolbox::Update.call(user:, operations:, source: "web")
end

DEMO_LAUNCHES.each do |slug, days_ago|
  AiModel.find_by!(slug:).update!(released_on: Date.current - days_ago, vibe_check_url: "https://checks.every.to/demo/#{slug}")
end

# Two open suggestions for Kieran to confirm in the Rank editor: one from a WebMCP tab
# (no OAuth client) and one from a connected client, which changes a pick he already has.
kieran = User.find_by!(email_address: "kieran@every.to")
unless kieran.pick_suggestions.exists?
  claude = OauthClient.find_or_create_by!(client_name: "Claude") { |client| client.redirect_uris = [ "http://127.0.0.1:33418/callback" ] }
  Toolbox::Update.call(user: kieran, source: "webmcp", operations: [ { op: "suggest", category: "research", tool: "perplexity", rank: 1 } ])
  Toolbox::Update.call(
    user: kieran, source: "mcp", client_name: claude.client_name, oauth_client_id: claude.id,
    operations: [ { op: "suggest", category: "coding", tool: "cursor", model: "composer-2-5", context: "200k", effort: "high" } ]
  )
end
