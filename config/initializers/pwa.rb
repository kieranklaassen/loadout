# frozen_string_literal: true

# PWA identity — the ONE place to rename or re-brand the installable app.
#
# Read by app/views/pwa/manifest.json.erb (web app manifest) and by
# app/views/layouts/application.html.erb (<title> fallback, application-name and
# theme-color metas), so the browser, the home-screen icon, and the page header
# always agree. Downstream apps edit these values and nothing else.
Rails.application.config.x.pwa.name = "Loadout"
Rails.application.config.x.pwa.short_name = "Loadout"
Rails.application.config.x.pwa.description = "The AI tools and models people actually use, one profile at a time."
Rails.application.config.x.pwa.theme_color = "#FAF8F3"
Rails.application.config.x.pwa.background_color = "#FAF8F3"
