require "test_helper"

class Toolbox::PickerPropsTest < ActiveSupport::TestCase
  def props(user, kind: nil)
    Toolbox::PickerProps.new(user, kinds: Toolbox::Presenter.new(user).kinds, kind:).to_h
  end

  def slugs(items) = items.map { |item| item[:slug] }

  test "the catalog is the approved tools and models as Mark items, each with the kinds it suits" do
    catalog = props(users(:every_ana))[:catalog]

    assert_equal %w[cursor claude-code claude runway], slugs(catalog[:tools])
    assert_equal %w[claude-opus-5-5 claude-opus-5 gpt-6-astra], slugs(catalog[:models])
    assert_not_includes slugs(catalog[:tools]), "old-thing", "a hidden tool leaves the pickers"

    assert_equal tools(:cursor).to_prop.merge(suggested_for: [ "coding" ], models: []), catalog[:tools].first
    assert_equal ai_models(:opus_5_5).to_prop.merge(suggested_for: %w[coding knowledge-work]), catalog[:models].first
  end

  test "each tool lists the approved models it runs, its own first, and none when the catalog does not know" do
    tools(:claude_code).update!(paired_models: %w[gpt claude-opus])
    ai_models(:opus_5).update!(status: "hidden")

    tools = props(users(:every_ana))[:catalog][:tools].index_by { |tool| tool[:slug] }
    assert_equal %w[gpt-6-astra claude-opus-5-5], tools["claude-code"][:models]
    assert_equal [], tools["cursor"][:models]
  end

  test "suggested_for lists only kinds that exist" do
    tools(:cursor).update!(category_slugs: %w[coding other])

    assert_equal [ "coding" ], props(users(:every_ana))[:catalog][:tools].first[:suggested_for]
  end

  test "a member's own pending items are offered to them, and nobody else's" do
    mine = Tool.create!(name: "Zed", status: "pending", created_by: users(:every_ana))
    theirs = Tool.create!(name: "Windsurf", status: "pending", created_by: users(:every_dee))
    my_model = AiModel.create!(name: "Beta Model", status: "pending", created_by: users(:every_ana))

    ana = props(users(:every_ana))[:catalog]
    assert_includes slugs(ana[:tools]), mine.slug
    assert_not_includes slugs(ana[:tools]), theirs.slug
    assert_equal [ true ], ana[:models].select { |model| model[:slug] == my_model.slug }.map { |model| model[:pending] }

    assert_not_includes slugs(props(users(:every_dee))[:catalog][:tools]), mine.slug
  end

  test "the context and effort choices are the ones an entry accepts" do
    enums = props(users(:every_ana))[:enums]

    assert_equal({ context: %w[200k 1m], effort: %w[low medium high] }, enums)
    assert_equal({ context: Entry::CONTEXTS, effort: Entry::EFFORTS }, enums)
  end

  test "the open kind is the one asked for, else the first with fewer than three picks" do
    ana = users(:every_ana)

    assert_equal "video", props(ana, kind: "video")[:selected_kind]
    assert_equal "coding", props(ana)[:selected_kind], "coding has two picks"
    assert_equal "coding", props(ana, kind: "no-such-kind")[:selected_kind]

    Toolbox::Update.call(user: ana, operations: [ { op: "set_pick", category: "coding", rank: 3, tool: "runway" } ], source: "web")
    assert_equal "knowledge-work", props(ana)[:selected_kind]
  end

  test "the member's kinds are built when not passed in" do
    assert_equal "coding", Toolbox::PickerProps.new(users(:every_ana)).to_h[:selected_kind]
  end

  test "with every kind full the first kind opens" do
    user = users(:one)
    operations = %w[coding knowledge-work video].flat_map do |category|
      %w[cursor claude-code runway].each_with_index.map { |tool, index| { op: "set_pick", category:, rank: index + 1, tool: } }
    end
    Toolbox::Update.call(user:, operations:, source: "web")

    assert_equal "coding", props(user)[:selected_kind]
  end
end
