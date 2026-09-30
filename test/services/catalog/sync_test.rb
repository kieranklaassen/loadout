require "test_helper"

class Catalog::SyncTest < ActiveSupport::TestCase
  MARKS_DIR = Rails.root.join("app/frontend/assets/marks")

  test "loads the seeded catalog idempotently" do
    Catalog::Sync.call
    counts = [ Category.count, Tool.count, AiModel.count ]

    Catalog::Sync.call

    assert_equal counts, [ Category.count, Tool.count, AiModel.count ]
    assert_equal 12, Category.count
    assert_not Category.exists?(slug: "other")
    assert Tool.find_by!(slug: "claude-code").approved?
    assert_equal "claude-opus", AiModel.find_by!(slug: "claude-opus-5-5").family
  end

  test "seeds personal agents as a kind of work, right after knowledge work, with its agents" do
    Catalog::Sync.call

    category = Category.find_by!(slug: "personal-agents")
    assert_equal "Personal agents", category.name
    assert_equal "knowledge-work", Category.where("position < ?", category.position).last.slug

    agents = Tool.all.select { |tool| tool.category_slugs.include?("personal-agents") }.map(&:slug)
    assert_includes agents, "cora"
    assert_empty %w[instinct muse dots grok-bot poke gemini-spark openclaw] - agents
    assert_equal [ "Meta", "muse-spark" ], AiModel.find_by!(slug: "muse-spark-1-3").then { |model| [ model.maker, model.family ] }
  end

  test "never un-hides an admin-hidden item or overwrites a member suggestion" do
    suggestion = Tool.create!(slug: "cora", name: "My Cora", status: "pending", created_by: users(:one))
    Catalog::Sync.call
    Tool.find_by!(slug: "cursor").update!(status: "hidden")

    Catalog::Sync.call

    assert_equal "hidden", Tool.find_by!(slug: "cursor").status
    assert_equal "My Cora", suggestion.reload.name
  end

  test "every category in the catalog file is covered by at least one tool" do
    data = YAML.safe_load_file(Catalog::Sync::PATH, permitted_classes: [ Date ])
    tool_categories = data["tools"].flat_map { |tool| tool["categories"] }.uniq
    missing = data["categories"].map { |category| category["slug"] } - tool_categories

    assert_empty missing
  end

  test "keeps an admin's rename across syncs" do
    Catalog::Sync.call
    Tool.find_by!(slug: "cursor").update!(name: "Cursor IDE", admin_edited_at: Time.current)

    Catalog::Sync.call

    assert_equal "Cursor IDE", Tool.find_by!(slug: "cursor").name
  end

  test "writes each item's mark from the catalog" do
    Catalog::Sync.call

    assert_equal "cursor", Tool.find_by!(slug: "cursor").mark
    assert_equal "claudecode", Tool.find_by!(slug: "claude-code").mark
    assert_equal "claude", AiModel.find_by!(slug: "claude-opus-5-5").mark
    assert_equal "openai", AiModel.find_by!(slug: "gpt-6-astra").mark
    assert_nil Tool.find_by!(slug: "cora").mark
  end

  test "a mark removed from the catalog is cleared, even on an item an admin renamed" do
    tool = Tool.create!(slug: "acme", name: "Acme", monogram: "Ac", mark: "claude", admin_edited_at: Time.current)
    path = write_catalog(tools: [ { "slug" => "acme", "name" => "Acme", "hue" => 10, "monogram" => "Ac", "categories" => [] } ])

    Catalog::Sync.call(path:)

    assert_nil tool.reload.mark
  end

  test "every mark key in the catalog has an SVG, and every SVG is used" do
    data = YAML.safe_load_file(Catalog::Sync::PATH, permitted_classes: [ Date ])
    keys = (data["tools"] + data["models"]).filter_map { |item| item["mark"] }.uniq
    files = Dir[MARKS_DIR.join("*.svg")].map { |file| File.basename(file, ".svg") }

    assert_empty keys - files, "mark keys without an SVG in app/frontend/assets/marks"
    assert_empty files - keys, "SVGs no catalog item uses"
  end

  test "fills a model's release date and Vibe Check link when they are blank" do
    model = AiModel.create!(slug: "blank-model", name: "Blank Model", monogram: "Bm", status: "approved")

    Catalog::Sync.call(path: write_catalog(models: [ launch_row("blank-model", released_on: Date.new(2026, 8, 1), vibe_check_url: "https://checks.every.to/vibe-checks/blank") ]))

    model.reload
    assert_equal Date.new(2026, 8, 1), model.released_on
    assert_equal "https://checks.every.to/vibe-checks/blank", model.vibe_check_url
  end

  test "keeps a release date and Vibe Check link that are already set, even when the catalog differs" do
    opus = ai_models(:opus_5_5)
    date, link = opus.released_on, opus.vibe_check_url

    Catalog::Sync.call(path: write_catalog(models: [ launch_row(opus.slug, released_on: Date.new(2020, 1, 1), vibe_check_url: "https://checks.every.to/vibe-checks/other") ]))

    assert_equal [ date, link ], opus.reload.slice(:released_on, :vibe_check_url).values
  end

  test "leaves the launch fields an admin cleared alone" do
    model = AiModel.create!(slug: "cleared-model", name: "Cleared Model", monogram: "Cm", status: "approved", admin_edited_at: Time.current)

    Catalog::Sync.call(path: write_catalog(models: [ launch_row("cleared-model", released_on: Date.new(2026, 8, 1), vibe_check_url: "https://checks.every.to/vibe-checks/cleared") ]))

    assert_equal [ nil, nil ], model.reload.slice(:released_on, :vibe_check_url).values
  end

  test "syncing the shipped catalog does not wipe launch data an admin set" do
    opus = ai_models(:opus_5_5)
    date, link = opus.released_on, opus.vibe_check_url

    2.times { Catalog::Sync.call }

    assert_equal [ date, link ], opus.reload.slice(:released_on, :vibe_check_url).values
  end

  test "a catalog link off the allowlist fails the sync instead of being stored" do
    path = write_catalog(models: [ launch_row("evil-model", released_on: Date.new(2026, 8, 1), vibe_check_url: "https://evil.example/vibe") ])

    assert_raises(ActiveRecord::RecordInvalid) { Catalog::Sync.call(path:) }
    assert_not AiModel.exists?(slug: "evil-model")
  end

  test "a monogram YAML reads as a boolean fails the sync instead of being stored as text" do
    catalog = <<~YAML
      tools:
        - { slug: notion-ai, name: Notion AI, hue: 0, monogram: No, categories: [] }
    YAML

    error = assert_raises(ArgumentError) { Catalog::Sync.call(path: write_file(catalog)) }

    assert_match(/notion-ai.*monogram.*quote/i, error.message)
    assert_not Tool.exists?(slug: "notion-ai")
  end

  private

  def launch_row(slug, **launch)
    { "slug" => slug, "name" => slug.titleize, "hue" => 10, "monogram" => "Lm", "categories" => [] }.merge(launch.stringify_keys)
  end

  def write_catalog(catalog)
    write_file(catalog.deep_stringify_keys.to_yaml)
  end

  def write_file(contents)
    file = Tempfile.new([ "catalog", ".yml" ])
    file.write(contents)
    file.close
    (@catalog_files ||= []) << file
    file.path
  end
end
