require "test_helper"

class Toolbox::SlotsTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @coding = categories(:coding)
    @windsurf = Tool.create!(name: "Windsurf", status: "approved")
  end

  def slots(source: "web", client_name: nil)
    Toolbox::Slots.new(user: @user, category: @coding, source:, client_name:)
  end

  def place(rank, tool, **attributes)
    slots.place(rank:, tool:, ai_model: nil, **attributes)
  end

  def fill_three
    place(1, tools(:cursor))
    place(2, tools(:claude_code))
    place(3, @windsurf)
  end

  def ranked_tools
    @user.entries.order(:rank).map { |entry| [ entry.rank, entry.tool.slug ] }
  end

  test "placing a pick fills the slot and records the slot as it now stands" do
    change = slots(source: "mcp", client_name: "Claude Code").place(
      rank: 2, tool: tools(:cursor), ai_model: ai_models(:opus_5_5), context: "1m", effort: "high"
    )

    entry = @user.entries.sole
    assert_equal [ 2, "1m", "high" ], [ entry.rank, entry.context, entry.effort ]
    assert_equal [ "set", "mcp", "Claude Code" ], [ change.action, change.source, change.client_name ]
    assert_equal [ 2, nil, tools(:cursor).id, ai_models(:opus_5_5).id, "1m", "high" ],
      change.attributes.values_at("rank", "from_rank", "tool_id", "ai_model_id", "context", "effort")
    assert change.details["batch"].present?
    assert_replays_to_entries @user
  end

  test "placing on an occupied slot edits it in place and records the new state" do
    place(1, tools(:cursor), context: "200k")

    change = place(1, tools(:cursor), context: "1m", effort: "low")

    assert_equal [ "1m", "low" ], @user.entries.sole.attributes.values_at("context", "effort")
    assert_equal [ "set", 1, "1m", "low" ], [ change.action, change.rank, change.context, change.effort ]
    assert_equal 2, @user.entry_changes.count
    assert_replays_to_entries @user
  end

  test "placing exactly what is already there writes nothing" do
    place(1, tools(:cursor), context: "200k")

    assert_no_difference -> { EntryChange.count } do
      assert_nil place(1, tools(:cursor), context: "200k")
    end
  end

  test "a tool already ranked elsewhere in the kind is a readable error" do
    place(1, tools(:cursor))

    error = assert_raises(Toolbox::Update::Error) { place(2, tools(:cursor)) }

    assert_equal "Cursor is already your 1st pick for coding.", error.message
    assert_equal [ [ 1, "cursor" ] ], ranked_tools
  end

  test "a fourth pick is rejected because ranks stop at three" do
    fill_three

    error = assert_raises(Toolbox::Update::Error) { place(4, tools(:runway)) }

    assert_match(/up to 3 picks/, error.message)
    assert_equal 3, @user.entries.count
  end

  test "picks may sit in any slots, and one rank never holds two picks" do
    place(3, tools(:cursor))
    place(1, tools(:claude_code))

    assert_equal [ [ 1, "claude-code" ], [ 3, "cursor" ] ], ranked_tools
    assert_replays_to_entries @user
  end

  test "removing the middle pick closes the gap and records removed plus moved in one batch" do
    fill_three

    changes = slots.remove(rank: 2)

    assert_equal [ [ 1, "cursor" ], [ 2, "windsurf" ] ], ranked_tools
    assert_equal %w[removed moved], changes.map(&:action)
    removed, moved = changes
    assert_equal [ tools(:claude_code).id, 2 ], [ removed.tool_id, removed.rank ]
    assert_equal [ @windsurf.id, 2, 3 ], [ moved.tool_id, moved.rank, moved.from_rank ]
    assert_equal 1, changes.map { |change| change.details["batch"] }.uniq.size
    assert_equal 1, changes.map(&:created_at).uniq.size
    assert_no_rank_above_the_limit
    assert_replays_to_entries @user
  end

  test "removing the first pick moves every later pick up" do
    fill_three

    changes = slots.remove(rank: 1)

    assert_equal [ [ 1, "claude-code" ], [ 2, "windsurf" ] ], ranked_tools
    assert_equal %w[removed moved moved], changes.map(&:action)
    assert_no_rank_above_the_limit
    assert_replays_to_entries @user
  end

  test "removing a pick above a gap leaves the ranks contiguous" do
    place(1, tools(:cursor))
    place(3, tools(:claude_code))

    slots.remove(rank: 1)

    assert_equal [ [ 1, "claude-code" ] ], ranked_tools
    assert_replays_to_entries @user
  end

  test "removing an empty slot is a readable error" do
    place(1, tools(:cursor))

    error = assert_raises(Toolbox::Update::Error) { slots.remove(rank: 2) }

    assert_equal "Nothing is ranked 2nd for coding.", error.message
  end

  test "moving down swaps with the neighbour under the unique indexes, in one batch" do
    fill_three

    changes = slots.move(rank: 1, direction: "down")

    assert_equal [ [ 1, "claude-code" ], [ 2, "cursor" ], [ 3, "windsurf" ] ], ranked_tools
    assert_equal %w[moved moved], changes.map(&:action)
    assert_equal [ [ 2, 1 ], [ 1, 2 ] ], changes.map { |change| [ change.rank, change.from_rank ] }
    assert_equal [ tools(:cursor).id, tools(:claude_code).id ], changes.map(&:tool_id)
    assert_equal 1, changes.map { |change| change.details["batch"] }.uniq.size
    assert_equal 1, changes.map(&:created_at).uniq.size
    assert_no_rank_above_the_limit
    assert_replays_to_entries @user
  end

  test "moving up swaps too, and keeps context and effort with each pick" do
    place(1, tools(:cursor), context: "1m")
    place(2, tools(:claude_code), effort: "low")

    slots.move(rank: 2, direction: "up")

    assert_equal [ [ 1, "claude-code", nil, "low" ], [ 2, "cursor", "1m", nil ] ],
      @user.entries.order(:rank).map { |entry| [ entry.rank, entry.tool.slug, entry.context, entry.effort ] }
    assert_replays_to_entries @user
  end

  test "a run of moves and removals never leaves a rank above three and always replays" do
    fill_three

    slots.move(rank: 3, direction: "up")
    assert_no_rank_above_the_limit
    slots.move(rank: 1, direction: "down")
    assert_no_rank_above_the_limit
    slots.remove(rank: 1)
    assert_no_rank_above_the_limit
    place(3, tools(:runway))
    slots.move(rank: 2, direction: "up")
    assert_no_rank_above_the_limit

    assert_replays_to_entries @user
  end

  test "moving past either end is a readable error and changes nothing" do
    place(1, tools(:cursor))
    place(2, tools(:claude_code))

    up = assert_raises(Toolbox::Update::Error) { slots.move(rank: 1, direction: "up") }
    down = assert_raises(Toolbox::Update::Error) { slots.move(rank: 2, direction: "down") }

    assert_equal "Cursor is already your first pick for coding.", up.message
    assert_equal "Claude Code is already your last pick for coding.", down.message
    assert_equal [ [ 1, "cursor" ], [ 2, "claude-code" ] ], ranked_tools
  end

  test "a batch stamps its rows when it first writes, not when it is built" do
    fill_three
    placing, moving, removing = slots, slots, slots
    travel 1.minute

    batches = [ [ placing.place(rank: 3, tool: tools(:runway)) ], moving.move(rank: 1, direction: "down"), removing.remove(rank: 1) ]

    assert_equal [ [ Time.current ] ] * 3, batches.map { |changes| changes.map(&:created_at).uniq }
    assert_equal [ [ 1, "cursor", Time.current ], [ 2, "runway", Time.current ] ],
      @user.entries.order(:rank).map { |entry| [ entry.rank, entry.tool.slug, entry.updated_at ] }
    assert_replays_to_entries @user
  end

  test "a move swaps with the next pick even when a slot between them is empty" do
    place(1, tools(:cursor))
    place(3, tools(:claude_code))

    slots.move(rank: 1, direction: "down")

    assert_equal [ [ 1, "claude-code" ], [ 3, "cursor" ] ], ranked_tools
    assert_replays_to_entries @user
  end
end
