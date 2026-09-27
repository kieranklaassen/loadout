require "test_helper"

class Catalog::SyncTest < ActiveSupport::TestCase
  test "loads the seeded catalog idempotently" do
    Catalog::Sync.call
    counts = [ Category.count, Tool.count, AiModel.count ]

    Catalog::Sync.call

    assert_equal counts, [ Category.count, Tool.count, AiModel.count ]
    assert_operator Category.count, :>=, 12
    assert Tool.find_by!(slug: "claude-code").approved?
    assert_equal "claude-opus", AiModel.find_by!(slug: "claude-opus-5-5").family
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
    missing = data["categories"].map { |category| category["slug"] } - tool_categories - [ "other" ]

    assert_empty missing
  end

  test "keeps an admin's rename across syncs" do
    Catalog::Sync.call
    Tool.find_by!(slug: "cursor").update!(name: "Cursor IDE", admin_edited_at: Time.current)

    Catalog::Sync.call

    assert_equal "Cursor IDE", Tool.find_by!(slug: "cursor").name
  end
end
