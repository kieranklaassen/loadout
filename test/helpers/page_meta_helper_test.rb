require "test_helper"

class PageMetaHelperTest < ActionView::TestCase
  test "a page with no preview of its own reads as Home and shows the site card" do
    meta = page_meta

    assert_equal "The AI tools Every uses", meta[:title]
    assert_equal "Which AI tools and models the Every team uses for each kind of work.", meta[:description]
    assert_equal "#{request.base_url}/og-default.png", meta[:image]
  end

  test "a controller's own preview replaces the defaults it names and keeps the rest" do
    @page_meta = { title: "Ana's loadout", noindex: true }

    meta = page_meta

    assert_equal "Ana's loadout", meta[:title]
    assert meta[:noindex]
    assert_equal PageMetaHelper::DEFAULT_DESCRIPTION, meta[:description]
    assert_equal "#{request.base_url}/og-default.png", meta[:image]
  end
end
