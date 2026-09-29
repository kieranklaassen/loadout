require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  include ViteRails::TagHelpers

  test "the built application CSS is inlined once, with no stylesheet link" do
    html = app_stylesheet_tag

    assert_equal 1, html.scan("<style>").size
    assert_includes html, "tailwindcss"
    assert_no_match(/<link/, html)
  end

  test "the page component's own CSS rides along" do
    html = app_stylesheet_tag("home/index")

    assert_equal 1, html.scan("<style>").size
    assert_includes html, ".hero"
    assert_not_includes app_stylesheet_tag("kinds/show"), ".hero-board"
  end

  test "under the Vite dev server the stylesheet stays a link" do
    vite = ViteRuby.instance
    vite.define_singleton_method(:dev_server_running?) { true }
    html = app_stylesheet_tag

    assert_match(/<link rel="stylesheet"/, html)
    assert_no_match(/<style/, html)
  ensure
    vite.singleton_class.send(:remove_method, :dev_server_running?)
  end
end
