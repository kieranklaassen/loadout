# frozen_string_literal: true

# Link-preview metadata for the layout. Controllers set @page_meta for pages that
# deserve a custom preview (public profiles); everything else gets the defaults.
module PageMetaHelper
  DEFAULT_DESCRIPTION = "The AI tools and models people actually use, per task. Claim your link and share your loadout."

  def page_meta
    base = request.base_url
    {
      title: "Loadout: what's in your AI loadout?",
      description: DEFAULT_DESCRIPTION,
      url: request.original_url,
      image: "#{base}/og-default.png"
    }.merge(@page_meta || {})
  end
end
