# frozen_string_literal: true

require "test_helper"

class ListCategoriesToolTest < ActiveSupport::TestCase
  def categories_for(user)
    result = ToolRegistry.call("list_categories", arguments: {}, user:, source: "webmcp")
    assert_equal false, result[:isError]
    JSON.parse(result[:content].first[:text])["categories"]
  end

  test "lists every category in catalog order with the member's confirmed pick counts" do
    categories = categories_for(users(:every_ana))

    assert_equal %w[coding knowledge-work video], categories.map { |category| category["slug"] }
    assert_equal [ 2, 1, 0 ], categories.map { |category| category["entries_count"] }
    assert_equal "Writing, reviewing, and shipping code.", categories.first["blurb"]
  end

  test "a suggestion is not a pick" do
    assert_equal 0, categories_for(users(:every_ana)).last["entries_count"], "ana has an open suggestion for video, not a pick"
  end

  test "the catalog has the 11 kinds of work and no other" do
    Catalog::Sync.call

    categories = categories_for(users(:every_ana))
    assert_equal 11, categories.size
    assert_not_includes categories.map { |category| category["slug"] }, "other"
  end
end
