require "test_helper"

# How change rows read as plain sentences and as a story (KTD7 owns the slot state
# they carry; entry_change_slot_state_test.rb covers that). Rows are built directly
# so each test states exactly which rows the writer would have left behind.
class EntryChangeTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @clock = Time.zone.local(2026, 9, 1, 12)
  end

  # Each row is a minute after the last unless it is given a time, so the story order is
  # the order they are written in. Rows in one batch share a time.
  def change(action, tool: :cursor, model: nil, category: :coding, source: "web", at: (@clock += 1.minute), **attributes)
    EntryChange.create!(
      user: @user, category: categories(category), tool: tools(tool), ai_model: (ai_models(model) if model),
      action:, source:, created_at: at, **attributes
    )
  end

  def story
    EntryChange.story(@user.entry_changes.recent_first).map { |item| item[:sentence] }
  end

  test "a pick set in a slot names the pick, its setup and its place" do
    assert_equal "Set Cursor with Claude Opus 5.5 (1M context, high effort) as first pick for coding",
      change("set", model: :opus_5_5, rank: 1, context: "1m", effort: "high").sentence
    assert_equal "Set Claude Code as second pick for coding", change("set", tool: :claude_code, rank: 2).sentence
    assert_equal "Set Runway (200K context) as third pick for video", change("set", tool: :runway, category: :video, rank: 3, context: "200k").sentence
    assert_equal "Set Cursor (low effort) as first pick for coding", change("set", rank: 1, effort: "low").sentence
  end

  test "a move says where the pick came from and where it went" do
    assert_equal "Moved Cursor with Claude Opus 5.5 from second to first pick for coding", change("moved", model: :opus_5_5, rank: 1, from_rank: 2).sentence
    assert_equal "Moved Claude Code from first to second pick for coding", change("moved", tool: :claude_code, rank: 2, from_rank: 1).sentence
  end

  test "a confirmed suggestion reads as the member's own confirmation" do
    assert_equal "Confirmed Cursor with Claude Opus 5.5 (high effort) as first pick for coding",
      change("confirmed", model: :opus_5_5, rank: 1, effort: "high", source: "web", client_name: "Claude").sentence
  end

  test "a suggestion names the agent that made it" do
    assert_equal "Claude suggested Cursor for coding", change("suggested", source: "mcp", client_name: "Claude").sentence
    assert_equal "Claude Code suggested Cursor with Claude Opus 5.5 (1M context) for coding",
      change("suggested", model: :opus_5_5, context: "1m", source: "mcp", client_name: "Claude Code").sentence
  end

  test "a suggestion from an agent without a name still reads plainly" do
    assert_equal "An agent suggested Runway for video", change("suggested", tool: :runway, category: :video, source: "webmcp").sentence
  end

  test "a dismissed suggestion says what was turned down" do
    assert_equal "Dismissed the suggestion of Cursor with Claude Opus 5.5 for coding", change("dismissed", model: :opus_5_5).sentence
  end

  test "a removal reads as it did before ranks" do
    assert_equal "Stopped using Cursor for coding", change("removed", rank: 2).sentence
  end

  test "a baseline row, if asked, says it was carried over" do
    assert_equal "Carried over Claude Code with Claude Opus 5.5 as first pick for coding",
      change("baseline", tool: :claude_code, model: :opus_5_5, rank: 1, source: "system").sentence
  end

  test "legacy actions keep their v1 sentences" do
    assert_equal "Added Cursor with Claude Opus 5 for coding", change("added", model: :opus_5).sentence
    assert_equal "Made Claude Code the go-to for coding", change("made_primary", tool: :claude_code).sentence
    assert_equal "Updated the note on Claude Code for coding", change("updated", tool: :claude_code).sentence
  end

  test "an action nobody planned for reads neutrally instead of raising" do
    row = change("removed", rank: 1)
    row.update_column(:action, "rewrote")

    assert_equal "Changed Cursor for coding", row.reload.sentence
    assert_equal [ "Changed Cursor for coding" ], story
  end

  test "a slot row missing its rank still narrates" do
    assert_equal "Set Cursor as a pick for coding", change("set").sentence
    assert_equal "Moved Cursor to a pick for coding", change("moved").sentence
  end

  test "a client name is used as plain text, never as markup" do
    assert_equal "<b>Claude</b> & co suggested Cursor for coding", change("suggested", source: "mcp", client_name: "<b>Claude</b> & co").sentence
  end

  test "baseline rows never appear in the story" do
    at = @clock += 1.minute
    change("baseline", tool: :claude_code, rank: 1, source: "system", details: { batch: "migration" }, at:)
    change("baseline", rank: 2, source: "system", details: { batch: "migration" }, at:)

    assert_empty story
    assert_empty EntryChange.story(@user.entry_changes)
    assert_empty EntryChange.story(@user.entry_changes.narrated)
  end

  test "the narrated scope leaves out baseline rows and keeps everything else" do
    baseline = change("baseline", rank: 1, source: "system")
    kept = %w[set moved removed confirmed suggested dismissed added].map { |action| change(action, rank: 1) }

    assert_equal kept.map(&:id).sort, @user.entry_changes.narrated.pluck(:id).sort
    assert_includes @user.entry_changes.pluck(:id), baseline.id
  end

  test "a suggestion shows in the owner's story with the rows around it" do
    change("set", tool: :claude_code, rank: 1, details: { batch: "a" })
    change("suggested", tool: :runway, category: :video, source: "mcp", client_name: "Claude", rank: 1, details: { batch: "b" })
    change("baseline", rank: 2, source: "system")

    assert_equal [ "Claude suggested Runway for video", "Set Claude Code as first pick for coding" ], story
  end

  test "each item carries its row's id, action, source and client name" do
    row = change("suggested", source: "mcp", client_name: "Claude")

    assert_equal(
      { id: row.id, sentence: "Claude suggested Cursor for coding", action: "suggested", source: "mcp", client_name: "Claude", created_at: row.created_at.iso8601 },
      EntryChange.story([ row ]).sole
    )
  end

  test "a whole ranked history reads newest first, one line per row" do
    change("suggested", model: :opus_5_5, source: "mcp", client_name: "Claude", details: { batch: "1" })
    change("confirmed", model: :opus_5_5, rank: 1, details: { batch: "2" })
    change("set", tool: :claude_code, rank: 2, details: { batch: "3" })
    change("dismissed", tool: :runway, category: :video, details: { batch: "4" })
    change("removed", rank: 1, details: { batch: "5" })

    assert_equal [
      "Stopped using Cursor for coding",
      "Dismissed the suggestion of Runway for video",
      "Set Claude Code as second pick for coding",
      "Confirmed Cursor with Claude Opus 5.5 as first pick for coding",
      "Claude suggested Cursor with Claude Opus 5.5 for coding"
    ], story
  end

  test "a swap reads as two moves" do
    at = @clock += 1.minute
    change("moved", model: :opus_5_5, rank: 1, from_rank: 2, details: { batch: "swap" }, at:)
    change("moved", tool: :claude_code, rank: 2, from_rank: 1, details: { batch: "swap" }, at:)

    assert_equal [ "Moved Claude Code from first to second pick for coding", "Moved Cursor with Claude Opus 5.5 from second to first pick for coding" ], story
  end

  test "a removal and the move that closes its gap stay two lines, not a switch" do
    at = @clock += 1.minute
    change("removed", rank: 2, details: { batch: "compact" }, at:)
    change("moved", tool: :claude_code, rank: 2, from_rank: 3, details: { batch: "compact" }, at:)

    assert_equal [ "Moved Claude Code from third to second pick for coding", "Stopped using Cursor for coding" ], story
  end

  test "a removal and a new pick in one batch stay two lines" do
    at = @clock += 1.minute
    change("removed", rank: 1, details: { batch: "replace" }, at:)
    change("set", tool: :claude_code, rank: 1, details: { batch: "replace" }, at:)

    assert_equal [ "Set Claude Code as first pick for coding", "Stopped using Cursor for coding" ], story
  end

  test "a legacy model switch in one batch reads as one switch" do
    change("added", model: :opus_5, details: { batch: "before" })
    at = @clock += 1.minute
    change("removed", model: :opus_5, details: { batch: "switch" }, at:)
    change("added", model: :opus_5_5, details: { batch: "switch" }, at:)

    assert_equal [ "Switched coding model from Claude Opus 5 to Claude Opus 5.5 in Cursor", "Added Cursor with Claude Opus 5 for coding" ], story
    assert_equal "switched", EntryChange.story(@user.entry_changes.recent_first).first[:action]
  end

  test "a legacy tool switch in one batch reads as a switch between tools" do
    change("added", details: { batch: "before" })
    at = @clock += 1.minute
    change("removed", details: { batch: "switch" }, at:)
    change("added", tool: :claude_code, model: :opus_5_5, details: { batch: "switch" }, at:)

    assert_equal "Switched coding from Cursor to Claude Code with Claude Opus 5.5", story.first
  end

  test "legacy additions, removals, notes and go-to changes read plainly" do
    change("added", details: { batch: "1" })
    change("added", tool: :claude_code, details: { batch: "2" })
    change("made_primary", tool: :claude_code, details: { batch: "3" })
    change("updated", tool: :claude_code, details: { batch: "4" })
    change("removed", details: { batch: "5" })

    assert_equal [
      "Stopped using Cursor for coding",
      "Updated the note on Claude Code for coding",
      "Made Claude Code the go-to for coding",
      "Added Claude Code for coding",
      "Added Cursor for coding"
    ], story
  end

  test "a legacy pick removed and re-added in one batch tells no story" do
    change("added", model: :opus_5, details: { batch: "before" })
    at = @clock += 1.minute
    change("removed", model: :opus_5, details: { batch: "again" }, at:)
    change("added", model: :opus_5, details: { batch: "again" }, at:)

    assert_equal [ "Added Cursor with Claude Opus 5 for coding" ], story
  end

  test "the fixture histories narrate, the suggestion included" do
    ana = users(:every_ana).entry_changes.includes(:category, :tool, :ai_model)

    assert_equal ana.size, EntryChange.story(ana).size
    assert_includes EntryChange.story(ana).map { |item| item[:sentence] }, "WebMCP suggested Runway for video"
    EntryChange.includes(:category, :tool, :ai_model).each { |row| assert_kind_of String, row.sentence, row.id }
  end
end
