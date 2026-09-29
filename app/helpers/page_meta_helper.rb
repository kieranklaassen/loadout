# frozen_string_literal: true

# Link-preview metadata for the layout. Controllers set @page_meta for pages that
# deserve a custom preview (a profile); everything else gets Home's wording and the
# site card.
module PageMetaHelper
  DEFAULT_TITLE = "The AI tools Every uses"
  DEFAULT_DESCRIPTION = "Which AI tools and models the Every team uses for each kind of work."

  def page_meta
    base = request.base_url
    {
      title: DEFAULT_TITLE,
      description: DEFAULT_DESCRIPTION,
      url: request.original_url,
      image: "#{base}/og-default.png"
    }.merge(@page_meta || {})
  end
end
