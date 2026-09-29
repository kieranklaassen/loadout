require "test_helper"

# The stylesheet is inlined into every page's HTML, so anything embedded in it is paid for on every
# load. Vite inlines assets under 4 KB as base64; fonts are kept as files so the rarely used
# subsets are fetched only when a character needs them (vite.config.ts, build.assetsInlineLimit).
class FontAssetsTest < ActiveSupport::TestCase
  test "the built stylesheet does not embed font files" do
    path = ViteRuby.instance.manifest.path_for("application.css", type: :stylesheet)
    css = File.read(Rails.public_path.join(path.delete_prefix("/")))

    assert_no_match(/data:font\//, css)
    assert_match(%r{url\(/vite[^)]*\.woff2\)}, css, "the fonts are still referenced, as files")
  end
end
