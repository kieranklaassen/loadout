require "test_helper"
require "open3"

class ProfileCardTest < ActiveSupport::TestCase
  MARKS_DIR = Rails.root.join("app/frontend/assets/marks")
  YELLOW = [ 246, 185, 15 ]
  PAGE = [ 2, 2, 2 ]

  setup { @ana = users(:every_ana) }

  # --- the rendering primitives the card is built from ----------------------------------

  test "librsvg draws an embedded JPEG and inline path data through svgload_buffer" do
    red = Vips::Image.black(20, 20).new_from_image([ 255, 0, 0 ]).copy(interpretation: :srgb)
    svg = <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="100" height="50" viewBox="0 0 100 50">
        <rect width="100" height="50" fill="#ffffff"/>
        <image href="data:image/jpeg;base64,#{[ red.write_to_buffer(".jpg", Q: 95) ].pack("m0")}" x="0" y="0" width="20" height="20"/>
        <g transform="translate(50 10)" fill="#0000ff"><path d="M0 0h20v20H0z"/></g>
      </svg>
    SVG

    Vips.block("VipsForeignLoadSvg", false)
    image = Vips::Image.svgload_buffer(svg)

    assert_pixel [ 255, 0, 0 ], image, 10, 10
    assert_pixel [ 0, 0, 255 ], image, 60, 20
    assert_pixel [ 255, 255, 255 ], image, 90, 40
  end

  test "pango draws the card's three faces from the vendored fonts, each in its own" do
    widths = [ "Hanken Grotesk", "Newsreader", "Geist Mono" ].map { |family| Vips::Image.text("Hamburgefonstiv", font: "#{family} 40").width }

    assert_equal 3, widths.uniq.size, "the faces are drawn alike (#{widths}), so pango is not reading vendor/fonts"
  end

  test "the vendored Hanken Grotesk and the other card faces resolve through fontconfig" do
    assert Rails.root.join("vendor/fonts/hanken-grotesk/OFL.txt").exist?
    skip "fc-match is not installed" unless system("which fc-match", out: File::NULL, err: File::NULL)

    env = { "FONTCONFIG_FILE" => Rails.root.join("config/fontconfig/fonts.conf").to_s }
    [ "Hanken Grotesk", "Newsreader", "Geist Mono" ].each do |family|
      matched, = Open3.capture2(env, "fc-match", "-f", "%{family}", family)

      assert_includes matched.split(","), family, "fontconfig matched #{matched.inspect} for #{family}"
    end
  end

  test "every mark is a 24x24 glyph made of paths only, which is all the card inlines" do
    files = MARKS_DIR.glob("*.svg")

    assert_operator files.size, :>, 0
    assert_equal files.map { |file| file.basename(".svg").to_s }.sort, ProfileCard::Artwork::MARKS.keys.sort
    files.each do |file|
      svg = Nokogiri::XML(file.read).remove_namespaces!

      assert_equal "0 0 24 24", svg.root["viewBox"], file.basename.to_s
      assert_equal %w[path svg], svg.xpath("//*").map(&:name).uniq.sort, "#{file.basename} has elements the card does not draw"
    end
  end

  # --- the picture -------------------------------------------------------------------------

  test "a link profile renders a 1200x630 dark card with the collage on a yellow panel" do
    image = image_of(ProfileCard.new(@ana))

    assert_equal [ 1200, 630 ], image.size
    assert_pixel PAGE, image, 20, 20
    assert_pixel YELLOW, image, 1050, 600
    assert_operator distance(YELLOW, image.getpoint(1050, 100)), :>, 60, "the collage is not drawn in the panel"
  end

  test "the site card draws the default headline and no picks" do
    card = ProfileCard.site
    svg = svg_of(card)

    assert_equal [ 1200, 630 ], image_of(card).size
    assert_not card.picks?
    assert_equal "The AI tools Every uses", svg.at_css("#headline").text
    assert_empty svg.css("#top-tools, #top-models")
  end

  test "the committed default card is the dark site card" do
    image = Vips::Image.new_from_file(Rails.public_path.join("og-default.png").to_s)

    assert_equal [ 1200, 630 ], image.size
    assert_pixel PAGE, image, 20, 20
    assert_pixel YELLOW, image, 1050, 600
  end

  # --- what is drawn -----------------------------------------------------------------------

  test "the top tools and models are the first picks of Ana's kinds, tools square and models round" do
    card = ProfileCard.new(@ana)
    svg = svg_of(card)

    assert_equal [ "Cursor", "Claude" ], card.tools.map(&:label)
    assert_equal [ "Claude Opus 5.5" ], card.models.map(&:label)
    assert_equal card.tools.map(&:label), drawn_names(svg, "top-tools")
    assert_equal card.models.map(&:label), drawn_names(svg, "top-models")
    assert_equal 2, svg.css("#top-tools rect").size
    assert_empty svg.css("#top-tools circle")
    assert_equal 1, svg.css("#top-models circle").size
    assert_empty svg.css("#top-models rect")
    assert_equal [ "TOP TOOLS", "TOP MODELS" ], svg.css("text").map(&:text).grep(/\ATOP /)
    assert_equal "Ana Every", svg.at_css("#headline").text
    assert_equal "Every", svg.at_css("#headline tspan").text
    assert_equal "italic", svg.at_css("#headline tspan")["font-style"]
  end

  test "a tool that leads two kinds outranks one that leads one, ties go to the first seen, repeats collapse and only three are drawn" do
    zed = add_person("zed")
    tool_a, tool_b, tool_c, tool_d, tool_e = %w[Aardvark Badger Camel Dingo Emu].map { |name| add_tool(name) }
    model_1, model_2, model_3, model_4 = %w[One Two Three Four].map { |name| add_model(name) }
    firsts = [ [ tool_a, model_1 ], [ tool_b, model_2 ], [ tool_b, model_1 ], [ tool_c, nil ], [ tool_d, model_3 ], [ tool_e, model_4 ] ]
    kinds = firsts.each_with_index.map { |(tool, model), index| add_kind("Kind #{index}", 10 + index).tap { |kind| add_pick(zed, kind, 1, tool, model:) } }
    # Second choices never count: were they counted, the Emu would lead three kinds and Four two.
    kinds.first(2).each { |kind| add_pick(zed, kind, 2, tool_e, model: model_4) }

    card = ProfileCard.new(zed)
    svg = svg_of(card)

    assert_equal %w[Badger Aardvark Camel], card.tools.map(&:label)
    assert_equal %w[One Two Three], card.models.map(&:label)
    assert_equal %w[Badger Aardvark Camel], drawn_names(svg, "top-tools")
    assert_equal %w[One Two Three], drawn_names(svg, "top-models")
  end

  test "a column with fewer than three items draws only those" do
    zed = add_person("zed")
    add_pick(zed, add_kind("Kind", 10), 1, add_tool("Aardvark"), model: add_model("One"))
    add_pick(zed, add_kind("Other", 11), 1, add_tool("Badger"))

    svg = svg_of(ProfileCard.new(zed))

    assert_equal 2, svg.css("#top-tools rect").size
    assert_equal 1, svg.css("#top-models circle").size
  end

  test "a person with no model picks gets the tools column alone, left-aligned under the name" do
    zed = add_person("zed")
    add_pick(zed, add_kind("Kind", 10), 1, add_tool("Aardvark"))

    card = ProfileCard.new(zed)
    svg = svg_of(card)

    assert_empty card.models
    assert_empty svg.css("#top-models")
    assert_equal ProfileCard::PAD_X.to_s, svg.at_css("#top-tools text")["x"]
    assert_equal ProfileCard::PAD_X.to_s, svg.at_css("#headline")["x"], "the name and the column share a left edge"
  end

  test "a tool with a mark draws it inline, and one without draws its first letter in the serif" do
    tools(:claude_code).update_columns(mark: "claudecode")
    claude_code_path = MARKS_DIR.join("claudecode.svg").read[/ d="([^"]+)"/, 1]
    zed = add_person("zed")
    add_pick(zed, categories(:coding), 1, tools(:claude_code))
    add_pick(zed, categories(:video), 1, tools(:cursor))

    group = svg_of(ProfileCard.new(zed)).at_css("#top-tools")

    assert_equal [ claude_code_path ], group.css("g path").map { |path| path["d"] }
    assert_equal %w[C], group.css("text").select { |text| text["font-family"] == "Newsreader" }.map(&:text)
    assert_equal [ "Claude Code", "Cursor" ], drawn_names(group, nil)
  end

  test "a mark key that is not a mark file draws the initial and reads no file" do
    tools(:cursor).update_columns(mark: "../../../../etc/hosts")
    zed = add_person("zed")
    add_pick(zed, categories(:coding), 1, tools(:cursor))

    card = ProfileCard.new(zed)

    assert_nil card.tools.first.mark
    assert_equal %w[C], svg_of(card).css("#top-tools text").select { |text| text["font-family"] == "Newsreader" }.map(&:text)
    assert_equal [ 1200, 630 ], image_of(card).size
  end

  test "a pending tool or model is never drawn, even on its owner's own card" do
    pending_tool = add_tool("Secret Tool", status: "pending")
    pending_model = add_model("Secret Model", status: "pending")
    zed = add_person("zed")
    add_pick(zed, add_kind("Kind", 10), 1, pending_tool, model: pending_model)
    add_pick(zed, add_kind("Other", 11), 1, add_tool("Aardvark"), model: pending_model)

    card = ProfileCard.new(zed)

    assert_equal %w[Aardvark], card.tools.map(&:label)
    assert_empty card.models
    assert_not_includes card.to_svg, "Secret"
  end

  test "a person with nothing a visitor may read has no card to draw" do
    only_pending = add_person("only-pending")
    add_pick(only_pending, add_kind("Kind", 10), 1, add_tool("Secret Tool", status: "pending"))

    assert_not ProfileCard.new(add_person("nobody")).picks?, "no picks"
    assert_not ProfileCard.new(only_pending).picks?, "only a pending pick"
    assert_not ProfileCard.new(users(:every_cy)).picks?, "only me"
    assert_not ProfileCard.new(users(:every_dee)).picks?, "Every team"
    assert ProfileCard.new(@ana).picks?
  end

  # --- strings -----------------------------------------------------------------------------

  test "member-supplied text is escaped, and control and format characters never reach the SVG" do
    @ana.update_columns(name: %(<script>alert(1)</script> & "x"))
    tools(:cursor).update_columns(name: "Cur\u0000sor‮​<b>")
    ai_models(:opus_5_5).update_columns(name: "Opus\u0007 ￾5.5\u{FFFF}")

    card = ProfileCard.new(@ana)
    svg = svg_of(card)

    assert_empty svg.css("script")
    assert_empty svg.css("b")
    assert_equal %(<script>alert(1)</script> & "x"), svg.at_css("#headline").text
    assert_includes card.to_svg, "&lt;script&gt;"
    assert_equal [ "Cur sor<b>", "Claude" ], card.tools.map(&:label)
    assert_equal [ "Opus 5.5" ], card.models.map(&:label)
    assert_empty card.to_svg.delete("\n").scan(/[\p{Cc}\p{Cf}\u{FFFE}\u{FFFF}]/), "characters librsvg's XML parser can choke on"
    assert_equal [ 1200, 630 ], image_of(card).size
  end

  test "a name that fits stays at full size, a long one shrinks to one line, a very long one is cut" do
    normal = font_size(ProfileCard.new(@ana))
    @ana.update_columns(name: "Ana Bartholomew Maximilian Klaassen")
    long = font_size(ProfileCard.new(@ana))
    @ana.update_columns(name: "Ana " * 60)
    huge = svg_of(ProfileCard.new(@ana)).at_css("#headline")

    assert_equal ProfileCard::HEADLINE_SIZE, normal
    assert_operator long, :<, ProfileCard::HEADLINE_SIZE
    assert_operator long, :>, ProfileCard::HEADLINE_MIN_SIZE
    assert_equal ProfileCard::HEADLINE_MIN_SIZE, huge["font-size"].to_i
    assert huge.text.end_with?("…")
    assert_operator huge.text.length, :<, 60
  end

  test "a long tool name is cut" do
    tools(:cursor).update_columns(name: "An extraordinarily long tool name indeed")

    label = ProfileCard.new(@ana).tools.first.label

    assert_equal ProfileCard::MAX_LABEL, label.length
    assert label.end_with?("…")
  end

  # --- the digest and the cache ------------------------------------------------------------

  test "the digest follows what is drawn and nothing else" do
    digest = ProfileCard.new(@ana).digest

    assert_match(/\A\h{64}\z/, digest)
    assert_equal digest, ProfileCard.new(@ana).digest

    @ana.update_columns(bio: "Something new", loadout_updated_at: Time.current)
    entries(:ana_claude_code).update!(effort: "high", context: "1m")
    assert_equal digest, ProfileCard.new(@ana.reload).digest, "a bio, a timestamp and a second choice are not drawn"

    {
      "a mark" => -> { tools(:cursor).update_columns(mark: "cursor") },
      "a tool's name" => -> { tools(:cursor).update_columns(name: "Cursor IDE") },
      "a model's name" => -> { ai_models(:opus_5_5).update_columns(name: "Opus 5.6") },
      "the person's name" => -> { @ana.update_columns(name: "Ana Klaassen") },
      "a first pick" => -> { entries(:ana_cursor).update!(tool: tools(:runway)) },
      "visibility" => -> { @ana.update!(visibility: "team") }
    }.each do |what, change|
      before = ProfileCard.new(@ana.reload).digest
      change.call

      assert_not_equal before, ProfileCard.new(@ana.reload).digest, what
    end
  end

  test "bumping the card version changes the digest and the cache key" do
    before = ProfileCard.new(@ana)
    digest, cache_key = before.digest, before.cache_key

    with_card_version(ProfileCard::VERSION + 1) do
      after = ProfileCard.new(@ana)

      assert_not_equal digest, after.digest
      assert_not_equal cache_key, after.cache_key
    end
  end

  test "a rendered card is cached by content, so editing a mark never serves the old card" do
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    stale = ProfileCard.new(@ana).to_png

    assert Rails.cache.exist?(ProfileCard.new(@ana).cache_key)
    assert_equal stale, ProfileCard.new(@ana).to_png

    tools(:cursor).update!(mark: "cursor")

    assert_not_equal stale, ProfileCard.new(@ana.reload).to_png
  ensure
    Rails.cache = original_cache
  end

  test "editing a tool's mark touches the members who show it, as editing its name does" do
    travel_to 1.hour.from_now do
      tools(:cursor).update!(mark: "cursor")

      assert_in_delta Time.current, @ana.reload.updated_at, 5, "Ana picked Cursor"
      assert_in_delta Time.current, users(:outside_eli).reload.updated_at, 5, "Eli picked Cursor"
      assert_operator users(:every_fay).reload.updated_at, :<, 30.minutes.ago, "Fay did not"
    end
  end

  private

  def add_kind(name, position)
    Category.create!(slug: name.parameterize, name:, position:)
  end

  def svg_of(card)
    Nokogiri::XML(card.to_svg, &:strict).remove_namespaces!
  end

  def image_of(card)
    Vips::Image.new_from_buffer(card.render, "")
  end

  def font_size(card)
    svg_of(card).at_css("#headline")["font-size"].to_i
  end

  # The item names of a column, in drawn order (initials are in the serif, names in the sans).
  def drawn_names(svg, group)
    scope = group ? svg.css("##{group} text") : svg.css("text")
    scope.select { |text| text["font-family"] == "Hanken Grotesk" }.map(&:text)
  end

  def distance(expected, actual)
    expected.zip(actual).sum { |a, b| (a - b).abs }
  end

  def assert_pixel(expected, image, x, y)
    actual = image.getpoint(x, y).first(3)

    assert_operator distance(expected, actual), :<=, 30, "pixel at #{x},#{y} is #{actual}, not #{expected}"
  end

  def with_card_version(version)
    original = ProfileCard::VERSION
    ProfileCard.send(:remove_const, :VERSION)
    ProfileCard.const_set(:VERSION, version)
    yield
  ensure
    ProfileCard.send(:remove_const, :VERSION)
    ProfileCard.const_set(:VERSION, original)
  end
end
