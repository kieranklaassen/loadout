# Server-rendered images (ProfileCard) draw text through librsvg, which finds
# fonts with fontconfig. Point it at the vendored OFL faces before the first
# render; fontconfig reads this variable once, when it initializes.
ENV["FONTCONFIG_FILE"] = Rails.root.join("config/fontconfig/fonts.conf").to_s

# On Linux pango always uses fontconfig. On macOS it defaults to CoreText, which
# ignores the file above and would draw the cards in system fonts.
ENV["PANGOCAIRO_BACKEND"] = "fc"
