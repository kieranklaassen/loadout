# Where Toolbox is served from, and the two Every sites it links to, in one place.
# PUBLIC_BASE_URL is the single knob: the OAuth issuer, share links, the MCP resource
# and every host printed on a page derive from it, so moving the app is a
# configuration change. Nothing else spells the host.
module ToolboxHost
  DEFAULT_HOST = "toolbox.every.to"
  JOIN_EVERY_URL = "https://every.to"
  ALL_VIBE_CHECKS_URL = "https://checks.every.to"

  module_function

  # The origin URLs are built on: PUBLIC_BASE_URL when it is set, otherwise the
  # request's own (development and tests).
  def base_url(request = nil)
    configured_base_url || request&.base_url || "https://#{DEFAULT_HOST}"
  end

  # "toolbox.every.to", as printed on pages, cards and messages.
  def host
    configured_base_url&.sub(%r{\Ahttps?://}, "") || DEFAULT_HOST
  end

  # A link that stays relative to the host (agent tool output, the WebMCP endpoint):
  # the path the app is served under, then the app's own path. Empty at a host root.
  def path_to(path)
    "#{URI.parse(base_url).path.chomp("/")}#{path}"
  end

  def configured_base_url
    Rails.configuration.x.public_base_url.presence
  end
  private_class_method :configured_base_url
end
