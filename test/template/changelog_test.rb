require "test_helper"
require "set"

class ChangelogTest < ActiveSupport::TestCase
  CHANGELOG_DIR = Rails.root.join("docs/changelog")
  ENTRIES = Dir.glob(CHANGELOG_DIR.join("*.md"))
    .reject { |p| File.basename(p) == "README.md" }
    .freeze
  MANIFEST = YAML.load_file(Rails.root.join(".template-manifest.yml")).freeze
  MANIFEST_MODULES = MANIFEST.fetch("modules").keys.to_set
  ALLOWED_TYPES = %w[feat fix refactor].freeze

  def frontmatter(path)
    content = File.read(path)
    match = content.match(/\A---\s*\n(.*?)\n---\s*\n/m)
    assert match, "#{File.basename(path)} must open with YAML frontmatter"
    YAML.safe_load(match[1])
  end

  test "there is at least one changelog entry" do
    assert ENTRIES.any?
  end

  test "every entry has valid frontmatter" do
    ENTRIES.each do |path|
      name = File.basename(path)
      fm = frontmatter(path)

      assert Gem::Version.correct?(fm["template_version"].to_s),
        "#{name}: template_version must be valid semver"
      assert_kind_of Array, fm["modules"], "#{name}: modules must be a list"
      assert fm["modules"].any?, "#{name}: modules must be non-empty"
      assert_includes ALLOWED_TYPES, fm["type"], "#{name}: type must be one of #{ALLOWED_TYPES.join('/')}"
    end
  end

  test "every entry's modules are real manifest modules (referential integrity)" do
    ENTRIES.each do |path|
      fm = frontmatter(path)
      unknown = fm["modules"].to_set - MANIFEST_MODULES
      assert unknown.empty?,
        "#{File.basename(path)} names modules absent from the manifest: #{unknown.to_a}"
    end
  end

  test "the seed entry exists and the manifest matches the newest entry version" do
    seed = CHANGELOG_DIR.join("0.1.0-001-initial-template.md")
    assert File.exist?(seed), "the 0.1.0 seed entry must exist"

    newest = ENTRIES.map { |p| Gem::Version.new(frontmatter(p)["template_version"]) }.max
    assert_equal Gem::Version.new(MANIFEST.fetch("template_version")), newest,
      "manifest template_version must equal the newest changelog entry version"
  end

  test "the changelog README documents the filter + apply algorithm" do
    readme = File.read(CHANGELOG_DIR.join("README.md"))
    assert_match(/filter \+ apply algorithm/i, readme)
  end
end
