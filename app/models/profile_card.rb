# frozen_string_literal: true

# The 1200x630 share card for a profile (and the site-wide default card): an SVG
# rendered to PNG by libvips/librsvg with the vendored fonts in vendor/fonts (see
# config/fontconfig/fonts.conf). The layout follows docs/design/every-loadout/pages/
# EveryShare2.dc.html: the name, the top three tools (square marks) and top three
# models (round marks), the Every lockup and a yellow collage panel.
#
# The card is drawn for a signed-out visitor whoever asks for it: only picks a visitor
# may read, never a pending item. What is drawn is picked from each kind's first pick:
# a tool (or model) ranks by the number of kinds it leads, ties by first appearance in
# category order. Marks and the logo are inlined from app/frontend/assets; every string
# is stripped of control and format characters and escaped before it reaches librsvg.
class ProfileCard
  WIDTH = 1200
  HEIGHT = 630
  PANEL_WIDTH = 300
  MAX_ITEMS = 3
  # Bump when the drawing changes: it changes every card's ETag and cache key.
  VERSION = 2

  PAGE = "#020202"
  PAPER = "#fdfaf7"
  INK = "#121212"
  SOFT = "#d0d0d0"
  MUTED = "#8c8d91"
  SKY = "#9ce5f5"
  YELLOW = "#f6b90f"

  SERIF = "Newsreader"
  SANS = "Hanken Grotesk"
  MONO = "Geist Mono"

  # Layout, from the mock. Blocks are placed the way its flex column does: top and
  # bottom padding, and the free space split evenly between the blocks.
  PAD_X = 56
  PAD_Y = 48
  CONTENT_WIDTH = WIDTH - PANEL_WIDTH - 2 * PAD_X
  LOGO_HEIGHT = 30
  LOCKUP_SIZE = 36
  LOCKUP_HEIGHT = LOCKUP_SIZE * 1.02
  HEADLINE_SIZE = 84
  HEADLINE_MIN_SIZE = 44
  HEADLINE_HEIGHT = HEADLINE_SIZE * 1.02
  LABEL_SIZE = 16
  LABEL_HEIGHT = LABEL_SIZE * 1.3
  LABEL_GAP = 8
  ROW_HEIGHT = 60
  TILE = 52
  COLUMN_GAP = 32
  COLUMN_WIDTH = (CONTENT_WIDTH - COLUMN_GAP) / 2
  NAME_SIZE = 26
  MAX_LABEL = 22
  SUBTITLE_SIZE = 28
  SUBTITLE_HEIGHT = SUBTITLE_SIZE * 1.3

  # How far a baseline sits below the middle of a line box: (ascent - descent) / 2 of each face.
  SERIF_MID = 0.235
  SANS_MID = 0.3485
  MONO_MID = 0.355

  SITE_HEADLINE = [ [ "The AI tools ", false ], [ "Every", true ], [ " uses", false ] ].freeze
  SITE_SUBTITLE = [ "Which AI tools and models the Every team", "uses for each kind of work." ].freeze

  Item = Data.define(:label, :mark)

  def self.site
    new(nil)
  end

  def initialize(user)
    @user = user
    @person = PersonPicks.new(viewer: nil).for(user) if user
  end

  # The tools and models drawn, best first, at most MAX_ITEMS each.
  def tools
    @tools ||= top_items(leaders.map { |pick| pick[:tool] })
  end

  def models
    @models ||= top_items(leaders.filter_map { |pick| pick[:model] })
  end

  # Whether a visitor can see anything to draw. The site card draws no picks.
  def picks?
    tools.any?
  end

  # A digest of everything drawn (and the card version): the response's ETag, and the
  # part of the cache key that makes a stale card impossible.
  def digest
    inputs = @user ? [ name, @user.visibility, tools.map(&:to_h), models.map(&:to_h) ] : :site
    Digest::SHA256.hexdigest([ VERSION, inputs ].to_json)
  end

  def cache_key
    [ "profile_card", VERSION, @user&.id, @user&.loadout_updated_at.to_i, @user&.updated_at.to_i, digest ].join("/")
  end

  def to_png
    Rails.cache.fetch(cache_key) { render }
  end

  # Active Storage blocks libvips' untrusted loaders process-wide, svgload among
  # them. This SVG is ours (every string is stripped and escaped), so only the SVG
  # loader is re-enabled, and again on each render in case something re-blocked it.
  def render
    Vips.block("VipsForeignLoadSvg", false)
    Vips::Image.svgload_buffer(to_svg).write_to_buffer(".png")
  end

  def to_svg
    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="#{WIDTH}" height="#{HEIGHT}" viewBox="0 0 #{WIDTH} #{HEIGHT}">
        <defs>
          <pattern id="dots" width="28" height="28" patternUnits="userSpaceOnUse"><circle cx="14" cy="14" r="1.5" fill="#fff" fill-opacity="0.07"/></pattern>
        </defs>
        <rect width="#{WIDTH}" height="#{HEIGHT}" fill="#{PAGE}"/>
        <rect width="#{WIDTH - PANEL_WIDTH}" height="#{HEIGHT}" fill="url(#dots)"/>
        #{panel}
        #{@user ? profile : site}
      </svg>
    SVG
  end

  private

  def name
    @name ||= clean(Audience.person(@user)[:name])
  end

  # The first pick of each kind, in category order.
  def leaders
    return [] unless @person

    @person[:kinds].filter_map { |kind| kind[:picks].first }
  end

  def top_items(items)
    counts = items.map { |item| item[:slug] }.tally
    items.uniq { |item| item[:slug] }
      .sort_by.with_index { |item, index| [ -counts[item[:slug]], index ] }
      .first(MAX_ITEMS)
      .map { |item| Item.new(label: clean(item[:name]).truncate(MAX_LABEL, omission: "…"), mark: (item[:mark] if Artwork::MARKS.key?(item[:mark]))) }
  end

  # Text a librsvg parser can take: no control, format or non-character code points.
  def clean(value)
    value.to_s.scrub("").gsub(/\p{Cc}/, " ").gsub(/[\p{Cf}\u{FFFE}\u{FFFF}]/, "").squish
  end

  def escape(value)
    ERB::Util.html_escape(value.to_s)
  end

  def profile
    columns = [ [ "TOP TOOLS", tools, false ], [ "TOP MODELS", models, true ] ].select { |_, items, _| items.any? }
    grid_height = LABEL_HEIGHT + LABEL_GAP + columns.map { |_, items, _| items.size }.max * ROW_HEIGHT
    lockup_top, headline_top, grid_top = stack(LOCKUP_HEIGHT, HEADLINE_HEIGHT, grid_height)

    <<~SVG
      #{lockup(lockup_top)}
      #{headline([ [ name.sub(/\S+\z/, ""), false ], [ name[/\S+\z/].to_s, true ] ], headline_top)}
      #{columns.each_with_index.map { |(label, items, round), index| column(label, items, round:, x: PAD_X + index * (COLUMN_WIDTH + COLUMN_GAP), top: grid_top) }.join("\n")}
    SVG
  end

  def site
    subtitle_height = SITE_SUBTITLE.size * SUBTITLE_HEIGHT
    lockup_top, headline_top, subtitle_top = stack(LOCKUP_HEIGHT, HEADLINE_HEIGHT, subtitle_height)

    <<~SVG
      #{lockup(lockup_top)}
      #{headline(SITE_HEADLINE, headline_top)}
      #{SITE_SUBTITLE.each_with_index.map { |line, index| text(line, x: PAD_X, y: baseline(subtitle_top + (index + 0.5) * SUBTITLE_HEIGHT, SUBTITLE_SIZE, SANS_MID), family: SANS, size: SUBTITLE_SIZE, fill: SOFT) }.join("\n")}
    SVG
  end

  # The tops of blocks stacked down the card with the free space shared evenly between them.
  def stack(*heights)
    gap = (HEIGHT - 2 * PAD_Y - heights.sum) / (heights.size - 1)
    heights.each_with_index.map { |_, index| PAD_Y + heights.first(index).sum + gap * index }
  end

  def baseline(middle, size, mid)
    (middle + mid * size).round(2)
  end

  def panel
    collage = Artwork.collage
    <<~SVG
      <rect x="#{WIDTH - PANEL_WIDTH}" width="#{PANEL_WIDTH}" height="#{HEIGHT}" fill="#{YELLOW}"/>
      <image href="#{collage.uri}" x="#{WIDTH - PANEL_WIDTH}" y="0" width="#{PANEL_WIDTH}" height="#{collage.height}"/>
    SVG
  end

  def lockup(top)
    scale = LOGO_HEIGHT / Artwork::LOGO_VIEW_HEIGHT
    logo_top = top + (LOCKUP_HEIGHT - LOGO_HEIGHT) / 2
    x = PAD_X + Artwork::LOGO_VIEW_WIDTH * scale + 14

    <<~SVG
      <g transform="translate(#{PAD_X} #{logo_top.round(2)}) scale(#{scale.round(5)})" fill="#{PAPER}">#{Artwork::LOGO}</g>
      #{text("Loadout", x: x.round(2), y: baseline(top + LOCKUP_HEIGHT / 2, LOCKUP_SIZE, SERIF_MID), family: SERIF, size: LOCKUP_SIZE, fill: SKY, style: "italic", spacing: -0.02 * LOCKUP_SIZE)}
    SVG
  end

  # The big serif line: segments are [text, italic sky] pairs. One line, shrunk to fit;
  # a name too long even then is cut.
  def headline(segments, top)
    length = [ segments.sum { |string, _| string.length }, 1 ].max
    size = [ HEADLINE_SIZE, (CONTENT_WIDTH / (length * 0.46)).floor ].min
    if size < HEADLINE_MIN_SIZE
      size = HEADLINE_MIN_SIZE
      segments = [ [ segments.map(&:first).join.truncate((CONTENT_WIDTH / (size * 0.46)).floor, omission: "…"), false ] ]
    end
    inner = segments.map { |string, italic| italic ? %(<tspan fill="#{SKY}" font-style="italic">#{escape(string)}</tspan>) : escape(string) }.join

    %(<text id="headline" x="#{PAD_X}" y="#{baseline(top + HEADLINE_HEIGHT / 2, size, SERIF_MID)}" font-family="#{SERIF}" font-size="#{size}" letter-spacing="#{-0.02 * size}" fill="#{PAPER}">#{inner}</text>)
  end

  def column(label, items, round:, x:, top:)
    rows = items.each_with_index.map { |item, index| item_row(item, round:, x:, top: top + LABEL_HEIGHT + LABEL_GAP + index * ROW_HEIGHT) }

    <<~SVG
      <g id="#{round ? "top-models" : "top-tools"}">
        #{text(label, x:, y: baseline(top + LABEL_HEIGHT / 2, LABEL_SIZE, MONO_MID), family: MONO, size: LABEL_SIZE, fill: MUTED, spacing: 0.1 * LABEL_SIZE)}
        #{rows.join("\n")}
      </g>
    SVG
  end

  # A light tile (square for a tool, round for a model) with the real mark or the
  # name's first letter in the serif, then the name.
  def item_row(item, round:, x:, top:)
    tile_top = top + (ROW_HEIGHT - TILE) / 2
    middle = tile_top + TILE / 2.0
    tile = round ? %(<circle cx="#{x + TILE / 2}" cy="#{middle}" r="#{TILE / 2}" fill="#{PAPER}"/>) : %(<rect x="#{x}" y="#{tile_top}" width="#{TILE}" height="#{TILE}" rx="4" fill="#{PAPER}"/>)

    <<~SVG
      #{tile}
      #{glyph(item, x:, tile_top:, size: round ? 27 : 29)}
      #{text(item.label, x: x + TILE + 16, y: baseline(top + ROW_HEIGHT / 2.0, NAME_SIZE, SANS_MID), family: SANS, size: NAME_SIZE, weight: 500, fill: PAPER)}
    SVG
  end

  def glyph(item, x:, tile_top:, size:)
    if item.mark
      offset = (TILE - size) / 2.0
      %(<g transform="translate(#{x + offset} #{tile_top + offset}) scale(#{(size / Artwork::MARK_SIZE.to_f).round(5)})" fill="#{INK}">#{Artwork::MARKS.fetch(item.mark)}</g>)
    else
      text(item.label.grapheme_clusters.first.to_s.upcase.presence || "?", x: x + TILE / 2, y: baseline(tile_top + TILE / 2.0, 22, SERIF_MID), family: SERIF, size: 22, weight: 500, fill: INK, anchor: "middle")
    end
  end

  def text(content, x:, y:, family:, size:, fill:, weight: 400, spacing: 0, anchor: "start", style: "normal")
    %(<text x="#{x}" y="#{y}" font-family="#{family}" font-size="#{size}" font-weight="#{weight}" font-style="#{style}" letter-spacing="#{spacing.round(2)}" text-anchor="#{anchor}" fill="#{fill}">#{escape(content)}</text>)
  end
end
