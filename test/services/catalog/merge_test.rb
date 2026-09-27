require "test_helper"

class Catalog::MergeTest < ActiveSupport::TestCase
  setup do
    @member = users(:one)
    @other = users(:two)
    @coding = categories(:coding)
    @source = Tool.resolve_or_suggest!("Claude-Code CLI", user: @member)
    @target = tools(:claude_code)
  end

  def pick(user, rank, tool, category: "coding", **fields)
    Loadouts::Update.call(user:, source: "web", operations: [ { op: "set_pick", category:, rank:, tool: tool.slug, **fields } ])
  end

  def coding_tools(user)
    user.entries.where(category: @coding).order(:rank).map { |entry| [ entry.rank, entry.tool ] }
  end

  def merge_rows(user)
    user.entry_changes.where(source: "system").order(:id)
  end

  def open_suggestion(user, tool, **fields)
    PickSuggestion.create!(user:, category: @coding, tool:, client_name: "Claude", oauth_client_id: 7, **fields)
  end

  def fields(record, *names)
    record.reload.attributes.values_at(*names.map(&:to_s))
  end

  # The unique indexes already forbid a repeated tool or rank; this adds what only
  # the merge can get wrong: a gap left where a pick was removed.
  def assert_loadouts_valid
    Entry.all.group_by { |entry| [ entry.user_id, entry.category_id ] }.each do |(user_id, category_id), entries|
      expected = (1..entries.size).to_a
      assert_equal expected, entries.map(&:rank).sort, "ranks should stay contiguous (user #{user_id}, category #{category_id})"
      assert_equal entries.size, entries.map(&:tool_id).uniq.size, "a tool is ranked twice (user #{user_id}, category #{category_id})"
    end
    assert_no_rank_above_the_limit
  end

  test "a member who ranked both tools keeps the lower rank, and the removal is a system change that replays" do
    pick(@member, 1, @target)
    pick(@member, 2, tools(:cursor))
    pick(@member, 3, @source, model: ai_models(:opus_5_5).slug, context: "1m")

    Catalog::Merge.call(source: @source, target: @target)

    assert_equal [ [ 1, @target ], [ 2, tools(:cursor) ] ], coding_tools(@member)
    removed = merge_rows(@member).sole
    assert_equal [ "removed", "system", nil, 3, @target.id ], removed.attributes.values_at("action", "source", "client_name", "rank", "tool_id")
    assert_not Tool.exists?(@source.id)
    assert_replays_to_entries @member
    assert_loadouts_valid
  end

  test "removing the lower-ranked duplicate moves the picks below it up, in one batch" do
    pick(@member, 1, @target)
    pick(@member, 2, @source)
    pick(@member, 3, tools(:cursor), model: ai_models(:opus_5).slug)

    Catalog::Merge.call(source: @source, target: @target)

    assert_equal [ [ 1, @target ], [ 2, tools(:cursor) ] ], coding_tools(@member)
    assert_equal ai_models(:opus_5), @member.entries.find_by!(rank: 2).ai_model
    rows = merge_rows(@member)
    assert_equal [ [ "removed", 2, nil ], [ "moved", 2, 3 ] ], rows.map { |row| [ row.action, row.rank, row.from_rank ] }
    assert_equal 1, rows.map { |row| row.details["batch"] }.uniq.size
    assert_equal [ @target.id, tools(:cursor).id ], rows.map(&:tool_id)
    assert_replays_to_entries @member
    assert_loadouts_valid
  end

  test "when the source is the higher pick it survives as the target, with its own model, context and effort" do
    pick(@member, 1, @source, model: ai_models(:opus_5_5).slug, context: "1m", effort: "high")
    pick(@member, 2, tools(:cursor))
    pick(@member, 3, @target, model: ai_models(:opus_5).slug)

    Catalog::Merge.call(source: @source, target: @target)

    first = @member.entries.find_by!(rank: 1)
    assert_equal [ @target, ai_models(:opus_5_5), "1m", "high" ], [ first.tool, first.ai_model, first.context, first.effort ]
    assert_equal [ [ 1, @target ], [ 2, tools(:cursor) ] ], coding_tools(@member)
    assert_equal [ [ "removed", 3, @target.id ] ], merge_rows(@member).map { |row| [ row.action, row.rank, row.tool_id ] }
    assert_replays_to_entries @member
    assert_loadouts_valid
  end

  test "a member with only the source keeps the rank, and the history now names the target" do
    pick(@member, 1, tools(:cursor))
    pick(@member, 2, @source)
    changes = @member.entry_changes.count

    Catalog::Merge.call(source: @source, target: @target)

    assert_equal [ [ 1, tools(:cursor) ], [ 2, @target ] ], coding_tools(@member)
    assert_equal changes, @member.entry_changes.count, "nothing was removed, so no new rows"
    assert_empty merge_rows(@member)
    assert_equal [ tools(:cursor).id, @target.id ], @member.entry_changes.order(:id).pluck(:tool_id)
    assert_replays_to_entries @member
  end

  test "the tool-unique rule is per kind: the source in one kind and the target in another both stay" do
    pick(@member, 1, @source)
    pick(@member, 1, @target, category: "knowledge-work")

    Catalog::Merge.call(source: @source, target: @target)

    assert_equal [ [ 1, @target ] ], coding_tools(@member)
    assert_equal [ [ 1, @target ] ], @member.entries.where(category: categories(:knowledge_work)).map { |entry| [ entry.rank, entry.tool ] }
    assert_empty merge_rows(@member)
    assert_replays_to_entries @member
  end

  test "every member ends valid whether or not they ranked both tools" do
    ana = users(:every_ana)
    pick(@member, 1, @source)
    pick(@member, 2, @target)
    pick(@other, 1, tools(:cursor))
    pick(@other, 2, @source)
    pick(ana, 3, @source)

    Catalog::Merge.call(source: @source, target: @target)

    assert_equal [ [ 1, @target ] ], coding_tools(@member)
    assert_equal [ [ 1, tools(:cursor) ], [ 2, @target ] ], coding_tools(@other)
    assert_equal [ [ 1, tools(:cursor) ], [ 2, @target ] ], coding_tools(ana)
    assert_equal [ 1, 0, 1 ], [ merge_rows(@member).count, merge_rows(@other).count, merge_rows(ana).count ]
    [ @member, @other, ana ].each { |user| assert_replays_to_entries user }
    assert_loadouts_valid
  end

  test "suggestions move to the target, and an open one that repeats the surviving pick is superseded" do
    pick(@member, 1, @target, model: ai_models(:opus_5).slug)
    pick(@member, 2, @source)
    repeats = open_suggestion(@member, @source, ai_model: ai_models(:opus_5))
    differs = open_suggestion(@member, @source, ai_model: ai_models(:opus_5_5), slot_hint: 2, replaces_rank: 2, replaces_tool_id: @source.id, replaces_ai_model_id: nil)
    dismissed = open_suggestion(@member, @source, status: "dismissed", resolved_at: 3.days.ago)
    someone_elses = open_suggestion(@other, @source)
    unrelated = open_suggestion(@member, tools(:cursor))

    Catalog::Merge.call(source: @source, target: @target)

    assert_equal [ "superseded", @target.id ], fields(repeats, :status, :tool_id)
    assert_not_nil repeats.resolved_at
    assert_equal [ "open", @target.id, ai_models(:opus_5_5).id, @target.id ], fields(differs, :status, :tool_id, :ai_model_id, :replaces_tool_id)
    assert_equal [ "dismissed", @target.id ], fields(dismissed, :status, :tool_id)
    assert_equal [ "open", @target.id ], fields(someone_elses, :status, :tool_id)
    assert_equal [ "open", tools(:cursor).id ], fields(unrelated, :status, :tool_id)
    assert_equal [ differs, someone_elses ].map(&:id), PickSuggestion.open.where(tool: @target).order(:id).pluck(:id)
  end

  test "a model merge repoints picks, history and suggestions, and a pick that ends up identical stays" do
    duplicate = AiModel.resolve_or_suggest!("Opus Five", user: @member)
    kept = ai_models(:opus_5)
    pick(@member, 1, tools(:cursor), model: duplicate.slug)
    pick(@member, 2, @target, model: kept.slug)
    pick(@member, 3, tools(:runway), model: duplicate.slug, effort: "low")
    repeats = open_suggestion(@member, tools(:cursor), ai_model: duplicate)
    differs = open_suggestion(@member, @target, ai_model: duplicate, effort: "high", replaces_rank: 2, replaces_tool_id: @target.id, replaces_ai_model_id: duplicate.id)

    Catalog::Merge.call(source: duplicate, target: kept)

    assert_equal [ [ 1, kept ], [ 2, kept ], [ 3, kept ] ], @member.entries.order(:rank).map { |entry| [ entry.rank, entry.ai_model ] }
    assert_empty merge_rows(@member)
    assert_not AiModel.exists?(duplicate.id)
    assert_equal [ kept.id ], @member.entry_changes.where.not(ai_model_id: nil).distinct.pluck(:ai_model_id)
    assert_equal "superseded", repeats.reload.status
    assert_equal [ "open", kept.id, kept.id ], fields(differs, :status, :ai_model_id, :replaces_ai_model_id)
    assert_replays_to_entries @member
    assert_loadouts_valid
  end

  test "the target takes on the source's kinds" do
    @source.update!(category_slugs: [ "coding", "video" ])

    Catalog::Merge.call(source: @source, target: @target)

    assert_equal %w[coding video], @target.reload.category_slugs
  end

  test "items of different kinds, or the same item, are refused and nothing changes" do
    pick(@member, 1, @source)

    error = assert_raises(Catalog::Merge::Error) { Catalog::Merge.call(source: @source, target: ai_models(:opus_5)) }
    assert_equal "Merge into an item of the same kind.", error.message
    error = assert_raises(Catalog::Merge::Error) { Catalog::Merge.call(source: @source, target: @source) }
    assert_equal "An item can't be merged into itself.", error.message

    assert_equal [ [ 1, @source ] ], coding_tools(@member)
    assert Tool.exists?(@source.id)
  end

  test "a merge that fails part-way leaves every pick and every history row as it was" do
    pick(@member, 1, @target)
    pick(@member, 2, @source)
    pick(@member, 3, tools(:cursor))
    open_suggestion(@member, @source)
    @target.update_column(:hue, 999)
    before = [ Entry.order(:id).pluck(:id, :rank, :tool_id), EntryChange.count, PickSuggestion.pluck(:id, :tool_id, :status) ]

    assert_raises(ActiveRecord::RecordInvalid) { Catalog::Merge.call(source: @source, target: @target) }

    assert_equal before, [ Entry.order(:id).pluck(:id, :rank, :tool_id), EntryChange.count, PickSuggestion.pluck(:id, :tool_id, :status) ]
    assert Tool.exists?(@source.id)
    assert_empty merge_rows(@member)
  end
end
