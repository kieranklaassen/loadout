# frozen_string_literal: true

# The 1200x630 share card for a profile (and the site-wide default card): an
# SVG template rendered to PNG by libvips/librsvg with the vendored fonts in
# vendor/fonts (see config/fontconfig/fonts.conf).
class ProfileCard
  WIDTH = 1200
  HEIGHT = 630
  MAX_ROWS = 6
  VERSION = 1

  PAPER = "#fdfaf7"
  PAPER_DEEP = "#f6f0e8"
  INK = "#121212"
  INK_SOFT = "#3c3c3c"
  INK_MUTED = "#6b6b6b"
  RULE = "#e7e0d6"
  BLUE = "#1652ea"

  SERIF = "Newsreader"
  SANS = "Inter"
  MONO = "Geist Mono"

  Row = Data.define(:category, :tool, :model)

  def self.site
    new(nil)
  end

  def initialize(user, host: "loadout.every.to")
    @user = user
    @host = host
  end

  def cache_key
    [ "profile_card", VERSION, @user&.id, @user&.loadout_updated_at.to_i, @user&.updated_at.to_i, @host ].join("/")
  end

  def to_png
    Rails.cache.fetch(cache_key) { render }
  end

  # Active Storage blocks libvips' untrusted loaders process-wide, svgload among
  # them. This SVG is ours (every user string is escaped), so only the SVG
  # loader is re-enabled, and again on each render in case something re-blocked it.
  def render
    Vips.block("VipsForeignLoadSvg", false)
    Vips::Image.svgload_buffer(to_svg).write_to_buffer(".png")
  end

  def to_svg
    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="#{WIDTH}" height="#{HEIGHT}" viewBox="0 0 #{WIDTH} #{HEIGHT}">
        <rect width="#{WIDTH}" height="#{HEIGHT}" fill="#{PAPER}"/>
        <rect x="600" width="#{WIDTH - 600}" height="#{HEIGHT}" fill="#{PAPER_DEEP}"/>
        <line x1="600" y1="0" x2="600" y2="#{HEIGHT}" stroke="#{RULE}" stroke-width="2"/>
        #{wordmark(72, 64)}
        #{@user ? identity : site_identity}
        #{rows_svg}
      </svg>
    SVG
  end

  def rows
    return sample_rows unless @user

    Loadouts::Presenter.new(@user).top_picks.first(MAX_ROWS).map do |category|
      entry = category[:entries].first
      Row.new(category: category[:name], tool: entry[:tool], model: entry[:model])
    end
  end

  private

  def identity
    name_lines, name_size = fit_name(@user.display_name)
    name_top = 344
    line_height = (name_size * 1.02).round
    names = name_lines.each_with_index.map do |line, index|
      text(line, x: 72, y: name_top + index * line_height, family: SERIF, size: name_size, weight: 500, fill: INK, spacing: -(name_size * 0.02).round(1))
    end
    handle_y = name_top + (name_lines.size - 1) * line_height + 58

    <<~SVG
      #{avatar(132, 222, 60)}
      #{names.join("\n")}
      #{text("#{@host}/#{@user.handle}", x: 72, y: handle_y, family: MONO, size: 24, fill: INK_MUTED)}
      #{footer}
    SVG
  end

  def site_identity
    <<~SVG
      #{text("What’s in your", x: 72, y: 300, family: SERIF, size: 74, weight: 500, fill: INK, spacing: -1.5)}
      #{text("AI loadout?", x: 72, y: 380, family: SERIF, size: 74, weight: 500, fill: INK, spacing: -1.5, style: "italic")}
      #{text("The tools and models people actually use,", x: 72, y: 456, family: SANS, size: 24, fill: INK_SOFT)}
      #{text("per task. Claim your link and share it.", x: 72, y: 490, family: SANS, size: 24, fill: INK_SOFT)}
      #{text(@host, x: 72, y: 566, family: MONO, size: 20, fill: INK_MUTED, spacing: 0.5)}
    SVG
  end

  def footer
    label = text("AI LOADOUT", x: 72, y: 566, family: MONO, size: 16, fill: INK_MUTED, spacing: 1.6)
    return label unless @user.every_member?

    <<~SVG
      <rect x="192" y="546" width="78" height="28" rx="14" fill="none" stroke="#{BLUE}" stroke-width="1.5"/>
      #{text("EVERY", x: 231, y: 566, family: MONO, size: 14, fill: BLUE, spacing: 1.4, anchor: "middle")}
      #{label}
    SVG
  end

  def rows_svg
    list = rows
    if list.empty?
      return <<~SVG
        #{text("No picks yet.", x: 660, y: 320, family: SERIF, size: 44, fill: INK_MUTED, style: "italic")}
      SVG
    end

    row_height = 78
    top = ((HEIGHT - list.size * row_height) / 2.0).round
    list.each_with_index.map { |row, index| row_svg(row, 660, top + index * row_height, last: index == list.size - 1) }.join("\n")
  end

  def row_svg(row, x, y, last:)
    tile = 52
    tool = row.tool
    colors = mark_colors(tool[:hue])
    detail_x = x + tile + 22
    tool_name = truncate(tool[:name], 22)
    model_name = row.model && truncate(row.model[:name], [ 34 - tool_name.length, 8 ].max)

    <<~SVG
      <rect x="#{x}" y="#{y + 12}" width="#{tile}" height="#{tile}" rx="14" fill="#{colors[:background]}" stroke="#{colors[:border]}" stroke-width="1.5"/>
      #{text(tool[:monogram], x: x + tile / 2, y: y + 12 + tile / 2 + 7, family: MONO, size: 19, weight: 500, fill: colors[:color], anchor: "middle")}
      #{text(row.category.upcase, x: detail_x, y: y + 30, family: MONO, size: 13, fill: INK_MUTED, spacing: 1.3)}
      <text x="#{detail_x}" y="#{y + 60}" font-family="#{SANS}" font-size="25" fill="#{INK}"><tspan font-weight="600">#{escape(tool_name)}</tspan>#{model_name ? %(<tspan dx="12" fill="#{INK_MUTED}" font-weight="400">#{escape(model_name)}</tspan>) : ""}</text>
      #{last ? "" : %(<line x1="#{x}" y1="#{y + 76}" x2="1128" y2="#{y + 76}" stroke="#{RULE}" stroke-width="1"/>)}
    SVG
  end

  def wordmark(x, y)
    <<~SVG
      <g transform="translate(#{x} #{y - 22}) scale(1.5)">
        <rect x="2" y="3" width="20" height="5" rx="2.5" fill="#{INK}"/>
        <rect x="2" y="9.5" width="14" height="5" rx="2.5" fill="#{BLUE}"/>
        <rect x="2" y="16" width="8" height="5" rx="2.5" fill="#{INK}" opacity="0.35"/>
      </g>
      #{text("Loadout", x: x + 44, y: y + 10, family: SERIF, size: 34, weight: 500, fill: INK, spacing: -0.5)}
    SVG
  end

  def avatar(cx, cy, r)
    <<~SVG
      <circle cx="#{cx}" cy="#{cy}" r="#{r}" fill="#{PAPER_DEEP}" stroke="#{RULE}" stroke-width="2"/>
      #{text(initials(@user.display_name), x: cx, y: cy + (r * 0.34).round, family: SERIF, size: (r * 0.9).round, weight: 500, fill: INK, anchor: "middle")}
    SVG
  end

  def text(content, x:, y:, family:, size:, fill:, weight: 400, spacing: 0, anchor: "start", style: "normal")
    %(<text x="#{x}" y="#{y}" font-family="#{family}" font-size="#{size}" font-weight="#{weight}" font-style="#{style}" letter-spacing="#{spacing}" text-anchor="#{anchor}" fill="#{fill}">#{escape(content)}</text>)
  end

  # Newsreader at display sizes averages about 0.46em per character; the left
  # column is ~470px, so long names wrap to two lines and then shrink.
  def fit_name(name)
    [ 76, 64, 54 ].each do |size|
      per_line = (470 / (size * 0.46)).floor
      lines = wrap(name, per_line)
      return [ lines, size ] if lines.size <= 2 && lines.all? { |line| line.length <= per_line }
    end
    per_line = (470 / (54 * 0.46)).floor
    [ wrap(name, per_line).first(2).map { |line| truncate(line, per_line) }, 54 ]
  end

  def wrap(value, width)
    value.split(/\s+/).each_with_object([]) do |word, lines|
      if lines.any? && (lines.last.length + word.length + 1) <= width
        lines.last << " " << word
      else
        lines << word.dup
      end
    end
  end

  def truncate(value, length)
    value.length > length ? "#{value[0, length - 1].rstrip}…" : value
  end

  def initials(name)
    parts = name.split(/\s+/).reject(&:blank?)
    letters = parts.size > 1 ? parts.first[0] + parts.last[0] : parts.first.to_s[0, 2]
    letters.presence&.upcase || "?"
  end

  def escape(value)
    ERB::Util.html_escape(value.to_s)
  end

  # Mirrors markColors() in app/frontend/components/tool_mark.tsx.
  def mark_colors(hue)
    { background: hsl(hue, 70, 92), color: hsl(hue, 65, 24), border: hsl(hue, 45, 80) }
  end

  def hsl(hue, saturation, lightness)
    s = saturation / 100.0
    l = lightness / 100.0
    a = s * [ l, 1 - l ].min
    channel = lambda do |n|
      k = (n + hue / 30.0) % 12
      ((l - a * [ [ k - 3, 9 - k, 1 ].min, -1 ].max) * 255).round
    end
    format("#%02x%02x%02x", channel.call(0), channel.call(8), channel.call(4))
  end

  def sample_rows
    [
      [ "Coding", "Claude Code", "CC", 18, "Claude Opus 5.5" ],
      [ "Knowledge work", "Claude", "Cl", 18, "Claude Opus 5.5" ],
      [ "Research", "Perplexity", "Px", 185, nil ],
      [ "Image", "Midjourney", "MJ", 250, nil ],
      [ "Video", "Runway", "Rw", 345, nil ],
      [ "Speech to text", "Whisper", "Wh", 160, nil ]
    ].map do |category, tool, monogram, hue, model|
      Row.new(category:, tool: { name: tool, monogram:, hue: }, model: model && { name: model })
    end
  end
end
