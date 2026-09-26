require "test_helper"
require "set"

class ManifestTest < ActiveSupport::TestCase
  MANIFEST = YAML.load_file(Rails.root.join(".template-manifest.yml")).freeze
  MODULE_DOCS = Dir.glob(Rails.root.join("docs/modules/*.md"))
    .map { |p| File.basename(p, ".md") }
    .reject { |n| n == "README" }
    .to_set

  test "the manifest parses with a semver template_version and a modules map" do
    assert Gem::Version.correct?(MANIFEST.fetch("template_version")), "template_version must be valid semver"
    assert_kind_of Hash, MANIFEST.fetch("modules")
  end

  test "every module was adopted at valid semver no newer than template_version" do
    template_version = Gem::Version.new(MANIFEST.fetch("template_version"))

    MANIFEST.fetch("modules").each do |name, version|
      assert Gem::Version.correct?(version.to_s), "#{name}: #{version.inspect} is not valid semver"
      assert Gem::Version.new(version.to_s) <= template_version,
        "#{name} adopted_at #{version} is newer than template_version #{template_version}"
    end
  end

  test "the template is born-complete: manifest keys match module docs 1:1" do
    manifest_modules = MANIFEST.fetch("modules").keys.to_set

    assert_equal MODULE_DOCS, manifest_modules,
      "manifest and docs/modules/*.md must correspond 1:1 — " \
      "undocumented keys: #{(manifest_modules - MODULE_DOCS).to_a}; " \
      "unregistered docs: #{(MODULE_DOCS - manifest_modules).to_a}"
  end

  test "the semver rule rejects an adopted_at newer than template_version" do
    # Guards the comparison in the second test: a future version must sort higher.
    future = Gem::Version.new("999.0.0")
    assert future > Gem::Version.new(MANIFEST.fetch("template_version"))
  end
end
