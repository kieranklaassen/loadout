# frozen_string_literal: true

# PWA identity — the ONE place to rename or re-brand the installable app.
#
# Read by app/views/pwa/manifest.json.erb (web app manifest) and by
# app/views/layouts/application.html.erb (<title> fallback, application-name and
# theme-color metas), so the browser, the home-screen icon, and the page header
# always agree. Downstream apps edit these values and nothing else.
Rails.application.config.x.pwa.name = "Compound Stack Rails"
Rails.application.config.x.pwa.short_name = "Compound"
Rails.application.config.x.pwa.description = "The canonical Rails starter the fleet converges on."
Rails.application.config.x.pwa.theme_color = "#1f2937"
Rails.application.config.x.pwa.background_color = "#ffffff"
