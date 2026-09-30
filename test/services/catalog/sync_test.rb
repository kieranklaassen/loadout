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

  test "seeds OpenAI's current GPT-6, GPT-6.1 and GPT-5.6 models, newest first" do
    Catalog::Sync.call

    openai = AiModel.ordered.where(maker: "OpenAI").pluck(:name)
    lineup = [ "GPT-6 Astra", "GPT-6.1 Sol", "GPT-6 Sol", "GPT-5.6 Sol", "GPT-5.6 Terra", "GPT-6 Luna", "GPT-5.6 Luna" ]
    assert_equal lineup, openai & lineup
    assert_empty [ "GPT-Image-2.5 Sunburst", "GPT-Image-2.5 Flare", "GPT-Live 1", "GPT-Realtime-2.1", "GPT-Live-Transcribe", "GPT-4o mini TTS", "gpt-oss-120b" ] - openai
    assert_equal %w[coding knowledge-work research writing], AiModel.find_by!(slug: "gpt-6-1-sol").category_slugs
    assert_includes AiModel.find_by!(slug: "gpt-6-luna").category_slugs, "classification"
    assert_includes AiModel.find_by!(slug: "gpt-image-2-5-sunburst").category_slugs, "image"
    assert_includes AiModel.find_by!(slug: "gpt-live-transcribe").category_slugs, "speech-to-text"
    assert_includes AiModel.find_by!(slug: "gpt-4o-mini-tts").category_slugs, "text-to-speech"
  end

  test "names the models that never shipped under their catalog slug after the real ones" do
    Catalog::Sync.call

    renamed = %w[gpt-5-6 gpt-5-6-mini gemini-3-8-pro veo-4 deepseek-v4].index_with { |slug| AiModel.find_by!(slug:).name }
    assert_equal({ "gpt-5-6" => "GPT-5.6 Sol", "gpt-5-6-mini" => "GPT-5.6 Terra", "gemini-3-8-pro" => "Gemini 3.1 Pro", "veo-4" => "Veo 3.1", "deepseek-v4" => "DeepSeek V4 Pro" }, renamed)
  end

  test "seeds each vendor's current models with their makers" do
    Catalog::Sync.call

    makers = AiModel.where(slug: %w[claude-sonnet-5-5 gemini-omni-flash grok-build-0-1 muse-image-1-0 mistral-medium-3-5 deepseek-v4-1-flash qwen-3-8-max kimi-k2-7-code glm-5-3 eleven-v4 suno-v6]).pluck(:slug, :maker).to_h
    assert_equal({ "claude-sonnet-5-5" => "Anthropic", "gemini-omni-flash" => "Google", "grok-build-0-1" => "xAI", "muse-image-1-0" => "Meta",
                   "mistral-medium-3-5" => "Mistral AI", "deepseek-v4-1-flash" => "DeepSeek", "qwen-3-8-max" => "Alibaba", "kimi-k2-7-code" => "Moonshot AI",
                   "glm-5-3" => "Z.ai", "eleven-v4" => "ElevenLabs", "suno-v6" => "Suno" }, makers)
  end

  test "every catalog item has a unique slug and a unique name" do
    data = Catalog::Sync.data

    %w[tools models].each do |kind|
      assert_empty data[kind].map { |item| item["slug"] }.tally.select { |_, count| count > 1 }.keys, "duplicate #{kind} slugs"
      assert_empty data[kind].map { |item| item["name"].downcase }.tally.select { |_, count| count > 1 }.keys, "duplicate #{kind} names"
    end
  end

  test "pairs each tool with the models it runs, the tool's own first" do
    Catalog::Sync.call
    paired = ->(slug) { Tool.find_by!(slug:).paired_ai_models.map(&:slug) }

    assert_equal %w[veo-4 veo-3], paired.("veo")
    assert_equal %w[runway-gen-4-5 veo-4 veo-3], paired.("runway")
    assert_equal "composer-2-5", paired.("cursor").first
    assert_includes paired.("cursor"), "claude-opus-5-5"
    assert_empty paired.("claude-code").map { |slug| AiModel.find_by!(slug:).maker }.uniq - [ "Anthropic" ]
    assert_equal [ "jev" ], paired.("typesafe-jev")
    assert_equal [ "whisper-large-v3" ], paired.("macwhisper")
    assert_not Tool.find_by!(slug: "pika").paired?, "a tool whose models nobody lists pairs with nothing"
  end

  test "every model a tool lists is a family or a slug in the catalog, and no LLM pairs with a video-only tool" do
    data = Catalog::Sync.data
    known = data["models"].flat_map { |model| [ model["family"], model["slug"] ] }.compact
    listed = data["tools"].flat_map { |tool| Array(tool["models"]).flatten }.uniq

    assert_empty listed - known, "tool models that match no model family or slug"
    Catalog::Sync.call
    video_only = Tool.all.select { |tool| tool.category_slugs == [ "video" ] && tool.paired? }
    assert_not_empty video_only
    video_only.each do |tool|
      assert_empty tool.paired_ai_models.reject { |model| model.category_slugs.include?("video") || model.category_slugs.include?("image") }.map(&:slug), tool.slug
    end
  end

  test "a tool's paired models follow the catalog, even on a tool an admin renamed" do
    tool = Tool.create!(slug: "acme", name: "Acme IDE", monogram: "Ac", paired_models: [ "gpt" ], admin_edited_at: Time.current)
    Catalog::Sync.call(path: write_catalog(tools: [ { "slug" => "acme", "name" => "Acme", "hue" => 10, "monogram" => "Ac", "models" => [ [ "claude-opus" ], "jev" ] } ]))

    assert_equal %w[claude-opus jev], tool.reload.paired_models
    assert_equal "Acme IDE", tool.name
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
    data = Catalog::Sync.data
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
    data = Catalog::Sync.data
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
