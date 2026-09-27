# Demo members for local development and screenshots. Dev login lists them.
DEMO_MEMBERS = [
  { name: "Kieran Klaassen", email: "kieran@every.to", handle: "kieran", public: true, bio: "GM of Cora. Building with agents all day.",
    picks: {
      "coding" => [ %w[claude-code claude-opus-5-5], %w[cursor claude-opus-5-5], %w[codex gpt-6-astra] ],
      "knowledge-work" => [ %w[claude claude-opus-5-5], %w[cora] ],
      "classification" => [ %w[typesafe-jev jev] ],
      "speech-to-text" => [ %w[monologue] ],
      "video" => [ %w[runway runway-gen-4-5] ]
    } },
  { name: "Dan Shipper", email: "dan@every.to", handle: "dan", public: true, bio: "CEO of Every.",
    picks: {
      "writing" => [ %w[claude claude-fable-5-1], %w[spiral] ],
      "knowledge-work" => [ %w[chatgpt gpt-6-astra], %w[claude claude-opus-5-5] ],
      "coding" => [ %w[claude-code claude-opus-5-5] ],
      "research" => [ %w[chatgpt gpt-6-astra] ]
    } },
  { name: "Katie Parrott", email: "katie@every.to", handle: "katie", public: true,
    picks: {
      "writing" => [ %w[claude claude-fable-5-1] ],
      "image" => [ %w[midjourney midjourney-v8], %w[chatgpt-images gpt-image-2] ],
      "research" => [ %w[perplexity] ]
    } },
  { name: "Naveen Naidu", email: "naveen@every.to", handle: "naveen", public: false,
    picks: {
      "coding" => [ %w[cursor composer-2-5], %w[claude-code claude-opus-5] ],
      "classification" => [ %w[openai-api gpt-5-6-mini] ]
    } },
  { name: "Lucas Crespo", email: "lucas@every.to", handle: "lucas", public: true, bio: "Designing Every.",
    picks: {
      "image" => [ %w[midjourney midjourney-v8], %w[figma-weave nano-banana-2] ],
      "video" => [ %w[veo veo-4], %w[runway runway-gen-4-5] ],
      "animation" => [ %w[jitter], %w[kling kling-3] ]
    } },
  { name: "Brandon Gell", email: "brandon@every.to", handle: "brandon", public: false,
    picks: {
      "knowledge-work" => [ %w[claude claude-opus-5-5], %w[granola] ],
      "text-to-speech" => [ %w[elevenlabs eleven-v3] ]
    } }
].freeze

DEMO_MEMBERS.each do |member|
  user = User.find_or_initialize_by(email_address: member[:email])
  user.update!(name: member[:name], handle: member[:handle], public: member[:public], bio: member[:bio], onboarded_at: user.onboarded_at || Time.current)
  next if user.entries.exists?

  operations = member[:picks].flat_map do |category, picks|
    picks.each_with_index.map { |(tool, model), index| { op: "add", category:, tool:, model:, primary: index.zero? } }
  end
  Loadouts::Update.call(user:, operations:, source: "web")
end
