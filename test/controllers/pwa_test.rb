# frozen_string_literal: true

require "test_helper"

# The PWA surface is served by Rails' built-in Rails::PwaController, which sits
# outside InertiaController — so these endpoints must be public (no session) and
# must read their identity from config.x.pwa rather than hardcoded literals.
class PwaTest < ActionDispatch::IntegrationTest
  PWA = Rails.application.config.x.pwa

  def with_pwa_config(overrides)
    original = PWA.dup
    overrides.each { |key, value| PWA.public_send(:"#{key}=", value) }
    yield
  ensure
    original.each { |key, value| PWA.public_send(:"#{key}=", value) }
  end

  test "GET /manifest.json is public JSON with the installability fields" do
    get "/manifest.json"

    assert_response :success
    assert_equal "application/json", response.media_type

    manifest = JSON.parse(response.body)
    assert_equal "/", manifest["start_url"]
    assert_equal "/", manifest["scope"]
    assert_equal "standalone", manifest["display"]
    %w[name short_name theme_color background_color].each do |key|
      assert manifest[key].present?, "manifest must carry #{key}"
    end

    maskable = manifest.fetch("icons").find { |icon| icon["purpose"] == "maskable" }
    assert maskable, "manifest must carry a maskable icon"
    assert_equal "512x512", maskable["sizes"]
  end

  test "the manifest reads its identity from config.x.pwa" do
    with_pwa_config(name: "Overridden App", theme_color: "#123456") do
      get "/manifest.json"

      manifest = JSON.parse(response.body)
      assert_equal "Overridden App", manifest["name"]
      assert_equal "#123456", manifest["theme_color"]
    end
  end

  test "GET /service-worker is public JavaScript regardless of Accept header" do
    get "/service-worker"

    assert_response :success
    assert_equal "text/javascript", response.media_type
    assert_includes response.body, 'addEventListener("fetch"'
    assert_includes response.body, 'cache: "reload"'
  end

  test "mismatched formats 404 at routing instead of raising MissingTemplate" do
    %w[/manifest /manifest.xml /service-worker.json].each do |path|
      get path
      assert_response :not_found, "#{path} should 404 at routing, not 500 in the view layer"
    end
  end

  test "the layout links the manifest and matches theme-color to config" do
    get root_path

    assert_response :success
    assert_inertia_component "home/index"
    assert_select "link[rel=manifest][href='/manifest.json']"
    assert_select "meta[name=theme-color][content=?]", PWA.theme_color
  end

  test "the layout's application-name and default title read config.x.pwa" do
    with_pwa_config(name: "Overridden App") do
      get root_path

      assert_select "meta[name=application-name][content='Overridden App']"
      assert_select "title", text: "Overridden App"
    end
  end

  test "the offline page exists and is the path the service worker precaches" do
    offline = Rails.root.join("public/offline.html")
    assert offline.exist?, "public/offline.html must ship with the pwa module"

    get "/service-worker"
    assert_includes response.body, '"/offline.html"'
  end
end
