# frozen_string_literal: true

# The artwork the share card draws, read from the same files the web app uses
# (app/frontend/assets) so a card never shows a different mark or logo than a page.
#
# Marks are keyed by the files that exist when the app boots. A catalog `mark` value
# is only ever looked up in MARKS; it is never joined into a path.
module ProfileCard::Artwork
  ASSETS = Rails.root.join("app/frontend/assets")

  # Every mark is a 24x24 Simple Icons glyph (a test holds the files to that).
  MARK_SIZE = 24

  # The collage is shown 1100px wide, moved 330px left and 110px up, so only the
  # arch and the figure are in view. Cropping to that keeps the embedded JPEG small.
  COLLAGE_WIDTH = 1100
  COLLAGE_LEFT = 330
  COLLAGE_TOP = 110
  Collage = Data.define(:uri, :height)

  # The markup between <svg> and </svg>, to draw inside the card's own <g fill="...">.
  def self.inner_markup(file)
    file.read[%r{<svg[^>]*>(.*)</svg>}m, 1].to_s.strip
  end

  def self.view_box(file)
    file.read.match(/viewBox="0 0 ([\d.]+) ([\d.]+)"/).captures.map(&:to_f)
  end

  MARKS = ASSETS.join("marks").glob("*.svg").to_h { |file| [ file.basename(".svg").to_s, inner_markup(file) ] }.freeze

  LOGO = inner_markup(ASSETS.join("every-logo.svg"))
  LOGO_VIEW_WIDTH, LOGO_VIEW_HEIGHT = view_box(ASSETS.join("every-logo.svg"))

  # The visible part of the collage as a data URI, built once per process on first use.
  def self.collage
    @collage ||= begin
      image = Vips::Image.thumbnail(ASSETS.join("every-collage.jpg").to_s, COLLAGE_WIDTH)
      crop = image.crop(COLLAGE_LEFT, COLLAGE_TOP, ProfileCard::PANEL_WIDTH, image.height - COLLAGE_TOP)
      jpeg = crop.write_to_buffer(".jpg", Q: 85, strip: true)
      Collage.new(uri: "data:image/jpeg;base64,#{[ jpeg ].pack("m0")}", height: crop.height)
    end
  end
end
