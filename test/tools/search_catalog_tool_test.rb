# frozen_string_literal: true

require "test_helper"

class SearchCatalogToolTest < ActiveSupport::TestCase
  def search(arguments)
    result = ToolRegistry.call("search_catalog", arguments:, user: users(:every_ana), source: "webmcp")
    assert_equal false, result[:isError], result[:content].first[:text]
    JSON.parse(result[:content].first[:text])
  end

  test "matches names, slugs, and makers across tools and models, approved only" do
    found = search(query: "anthropic")

    assert_equal %w[claude-code claude], found["tools"].map { |tool| tool["slug"] }
    assert_includes found["models"].map { |model| model["slug"] }, "claude-opus-5-5"
    assert_empty search(query: "old thing")["tools"]
  end

  test "finds the synced OpenAI line-up by tier, version, and kind" do
    Catalog::Sync.call
    models = ->(query) { search(query:)["models"].map { |model| model["name"] } }

    assert_equal [ "GPT-6.1 Sol", "GPT-6 Sol", "GPT-5.6 Sol" ], models.("sol")
    assert_equal [ "GPT-6 Luna", "GPT-5.6 Luna" ], models.("luna")
    assert_equal [ "GPT-6.1 Sol" ], models.("6.1")
    assert_equal [ "GPT-Image-2.5 Sunburst", "GPT-Image-2.5 Flare", "GPT-Image-2" ], models.("gpt-image")
    assert_includes models.("transcribe"), "GPT-Live-Transcribe"
    assert_includes models.("mistral"), "Mistral Medium 3.5"
  end

  test "ranks items suggested for the category first" do
    found = search(query: "claude", category: "knowledge-work")

    assert_equal "claude", found["tools"].first["slug"]
    assert_equal [ "knowledge-work" ], found["tools"].first["categories"]
  end

  test "a category alone browses its suggestions" do
    assert_equal [ "runway" ], search(category: "video")["tools"].map { |tool| tool["slug"] }
  end

  test "a tool lists only the models it runs, and a query narrows them" do
    tools(:runway).update!(paired_models: %w[claude-opus])

    found = search(tool: "runway")
    assert_equal [ "runway" ], found["tools"].map { |tool| tool["slug"] }
    assert_equal %w[claude-opus-5-5 claude-opus-5], found["models"].map { |model| model["slug"] }
    assert_nil found["note"]
    assert_equal %w[claude-opus-5-5], search(tool: "runway", query: "5.5")["models"].map { |model| model["slug"] }
    assert_empty search(tool: "runway", query: "gpt")["models"]
  end

  test "a tool the catalog pairs with nothing says so and searches every model" do
    found = search(tool: "cursor", query: "gpt")

    assert_equal %w[gpt-6-astra], found["models"].map { |model| model["slug"] }
    assert_match(/does not list which models Cursor runs/, found["note"])
  end

  test "an unknown tool is a readable error" do
    result = ToolRegistry.call("search_catalog", arguments: { tool: "nope" }, user: users(:every_ana), source: "webmcp")

    assert result[:isError]
    assert_match(/Unknown tool "nope"/, result[:content].first[:text])
  end

  test "needs a query or a category, and a real category" do
    assert ToolRegistry.call("search_catalog", arguments: {}, user: users(:every_ana), source: "webmcp")[:isError]

    result = ToolRegistry.call("search_catalog", arguments: { category: "cooking" }, user: users(:every_ana), source: "webmcp")
    assert result[:isError]
    assert_match(/coding, knowledge-work, video/, result[:content].first[:text])
  end
end
