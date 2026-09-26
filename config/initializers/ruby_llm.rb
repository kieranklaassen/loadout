# frozen_string_literal: true

# Read a credential without raising when the master key is absent (test/CI have
# no config/master.key), so the app always boots even with no keys configured.
csr_credential = lambda do |*path|
  Rails.application.credentials.dig(*path)
rescue StandardError
  nil
end

RubyLLM.configure do |config|
  # Keys come from ENV first, then encrypted credentials. All optional: the app
  # boots and tests run with no keys — each provider is simply unavailable.
  config.openai_api_key = ENV["OPENAI_API_KEY"].presence || csr_credential.call(:openai, :api_key)
  config.anthropic_api_key = ENV["ANTHROPIC_API_KEY"].presence || csr_credential.call(:anthropic, :api_key)
  config.gemini_api_key = ENV["GEMINI_API_KEY"].presence || csr_credential.call(:gemini, :api_key)

  config.default_model = ENV.fetch("RUBY_LLM_MODEL", "gemini-2.5-flash")
  config.request_timeout = ENV.fetch("RUBY_LLM_REQUEST_TIMEOUT", "60").to_i
end

# Structured logging for every LLM chat completion, emitted through the app's
# normal Rails log pipeline. Defensive about payload shape so it never raises.
ActiveSupport::Notifications.subscribe("chat.ruby_llm") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  payload = event.payload
  tokens = payload[:total_tokens] || payload[:tokens]
  Rails.logger.info(
    "[ruby_llm] chat model=#{payload[:model]} duration=#{event.duration.round(1)}ms tokens=#{tokens}"
  )
end
