require "test_helper"

class ProfileCardTest < ActiveSupport::TestCase
  test "renders a 1200x630 PNG" do
    image = Vips::Image.new_from_buffer(ProfileCard.new(users(:every_ana)).render, "")

    assert_equal [ 1200, 630 ], [ image.width, image.height ]
  end

  test "shows the name, handle, and the go-to pick per category" do
    svg = ProfileCard.new(users(:every_ana)).to_svg

    assert_includes svg, "Ana Every"
    assert_includes svg, "loadout.every.to/ana"
    assert_includes svg, "Cursor"
    assert_includes svg, "Claude Opus 5.5"
    assert_includes svg, "KNOWLEDGE WORK"
    assert_includes svg, "EVERY"
  end

  test "escapes member-supplied text" do
    user = users(:every_ana)
    user.name = %(<script>&"x")

    svg = ProfileCard.new(user).to_svg

    assert_not_includes svg, "<script>"
    assert_includes svg, "&lt;script&gt;&amp;"
  end

  test "the cache key changes when the loadout changes" do
    user = users(:every_ana)
    before = ProfileCard.new(user).cache_key
    user.loadout_updated_at = 1.minute.from_now

    assert_not_equal before, ProfileCard.new(user).cache_key
  end

  test "the site card renders without a member" do
    image = Vips::Image.new_from_buffer(ProfileCard.site.render, "")

    assert_equal 1200, image.width
  end
end
