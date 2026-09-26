# frozen_string_literal: true

require "test_helper"

class ListCategoriesToolTest < ActiveSupport::TestCase
  test "lists every category in catalog order with the member's entry counts" do
    result = ToolRegistry.call("list_categories", arguments: {}, user: users(:every_ana), source: "webmcp")

    assert_equal false, result[:isError]
    categories = JSON.parse(result[:content].first[:text])["categories"]
    assert_equal %w[coding knowledge-work video], categories.map { |category| category["slug"] }
    assert_equal [ 1, 1, 0 ], categories.map { |category| category["entries_count"] }
    assert_equal "Writing, reviewing, and shipping code.", categories.first["blurb"]
  end
end
