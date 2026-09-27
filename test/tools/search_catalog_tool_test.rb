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

  test "ranks items suggested for the category first" do
    found = search(query: "claude", category: "knowledge-work")

    assert_equal "claude", found["tools"].first["slug"]
    assert_equal [ "knowledge-work" ], found["tools"].first["categories"]
  end

  test "a category alone browses its suggestions" do
    assert_equal [ "runway" ], search(category: "video")["tools"].map { |tool| tool["slug"] }
  end

  test "needs a query or a category, and a real category" do
    assert ToolRegistry.call("search_catalog", arguments: {}, user: users(:every_ana), source: "webmcp")[:isError]

    result = ToolRegistry.call("search_catalog", arguments: { category: "cooking" }, user: users(:every_ana), source: "webmcp")
    assert result[:isError]
    assert_match(/coding, knowledge-work, video/, result[:content].first[:text])
  end
end
