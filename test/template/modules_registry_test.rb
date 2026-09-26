require "test_helper"

class ModulesRegistryTest < ActiveSupport::TestCase
  MODULES_DIR = Rails.root.join("docs/modules")
  DOCS = Dir.glob(MODULES_DIR.join("*.md"))
    .reject { |p| File.basename(p) == "README.md" }
    .freeze

  test "there are module docs to register" do
    assert DOCS.any?, "expected docs/modules/*.md boundary docs"
  end

  test "every module doc declares purpose, boundary, adoption, and verification" do
    DOCS.each do |path|
      content = File.read(path)
      name = File.basename(path)

      assert_match(/\A# Module: /, content, "#{name} must open with '# Module: <name>'")
      assert_match(/Files \(the module boundary\)/, content, "#{name} must state its file boundary")
      assert_match(/Adopt into an existing app/, content, "#{name} must have an 'Adopt into an existing app' section (R8)")
      assert_match(/Verify adoption/, content, "#{name} must have a 'Verify adoption' section")
    end
  end

  test "the registry README lists every module doc" do
    readme = File.read(MODULES_DIR.join("README.md"))
    DOCS.each do |path|
      basename = File.basename(path)
      assert_includes readme, "(#{basename})", "docs/modules/README.md must link #{basename}"
    end
  end
end
