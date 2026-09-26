require "test_helper"

class Loadouts::UpdateTest < ActiveSupport::TestCase
  setup { @user = users(:one) }

  def update(*operations, source: "web", client_name: nil)
    Loadouts::Update.call(user: @user, operations:, source:, client_name:)
  end

  test "add creates an entry and records a dated change with its source" do
    result = update({ op: "add", category: "coding", tool: "cursor", model: "claude-opus-5-5" }, source: "mcp", client_name: "Claude Code")

    entry = @user.entries.sole
    assert_equal [ tools(:cursor), ai_models(:opus_5_5) ], [ entry.tool, entry.ai_model ]
    assert entry.primary?, "the first entry in a category becomes the go-to"
    change = result.changes.sole
    assert_equal [ "added", "mcp", "Claude Code" ], [ change.action, change.source, change.client_name ]
    assert_not_nil @user.reload.loadout_updated_at
  end

  test "tools and models resolve by name, case-insensitively" do
    update({ op: "add", category: "Coding", tool: "claude code", model: "Claude Opus 5.5" })

    assert_equal tools(:claude_code), @user.entries.sole.tool
  end

  test "adding the same pick twice is a no-op with no second change" do
    update({ op: "add", category: "coding", tool: "cursor" })

    assert_no_difference -> { EntryChange.count } do
      update({ op: "add", category: "coding", tool: "cursor" })
    end
  end

  test "an unknown tool becomes a pending catalog item that shows immediately" do
    assert_difference -> { Tool.pending.count } => 1 do
      update({ op: "add", category: "video", tool: "Hedra" })
    end

    tool = Tool.find_by!(name: "Hedra")
    assert_equal [ "pending", @user ], [ tool.status, tool.created_by ]
    assert_equal "He", tool.monogram
    assert_equal tool, @user.entries.sole.tool
  end

  test "set_primary moves the go-to mark and records made_primary" do
    update({ op: "add", category: "coding", tool: "cursor" }, { op: "add", category: "coding", tool: "claude-code" })

    result = update({ op: "set_primary", category: "coding", tool: "claude-code" })

    assert_equal [ "claude-code" ], @user.entries.where(primary: true).map { |entry| entry.tool.slug }
    assert_equal [ "made_primary" ], result.changes.map(&:action)
  end

  test "replace_category records only the diff" do
    update({ op: "add", category: "coding", tool: "cursor", model: "claude-opus-5" }, { op: "add", category: "coding", tool: "claude-code" })

    result = update({ op: "replace_category", category: "coding", picks: [
      { tool: "cursor", model: "claude-opus-5-5", primary: true },
      { tool: "claude-code" }
    ] })

    assert_equal %w[added made_primary removed], result.changes.map(&:action).sort
    assert_equal 2, @user.entries.count
    assert_equal ai_models(:opus_5_5), @user.entries.find_by(primary: true).ai_model
  end

  test "remove deletes the entry, records removed, and re-picks a go-to" do
    update({ op: "add", category: "coding", tool: "cursor", primary: true }, { op: "add", category: "coding", tool: "claude-code" })

    update({ op: "remove", category: "coding", tool: "cursor" })

    assert_equal [ tools(:claude_code) ], @user.entries.map(&:tool)
    assert @user.entries.sole.primary?
  end

  test "update_note records updated only when the note changes" do
    update({ op: "add", category: "coding", tool: "cursor" })

    result = update({ op: "update_note", category: "coding", tool: "cursor", note: "  Tab   is magic " })
    assert_equal "Tab is magic", @user.entries.sole.note
    assert_equal [ "updated" ], result.changes.map(&:action)

    assert_no_difference -> { EntryChange.count } do
      update({ op: "update_note", category: "coding", tool: "cursor", note: "Tab is magic" })
    end
  end

  test "errors name what went wrong" do
    error = assert_raises(Loadouts::Update::Error) { update({ op: "add", category: "cooking", tool: "cursor" }) }
    assert_match(/Unknown category "cooking"/, error.message)

    error = assert_raises(Loadouts::Update::Error) { update({ op: "remove", category: "coding", tool: "cursor" }) }
    assert_match(/not in your coding loadout/, error.message)

    error = assert_raises(Loadouts::Update::Error) { update({ op: "explode", category: "coding" }) }
    assert_match(/Unknown operation/, error.message)

    assert_raises(Loadouts::Update::Error) { Loadouts::Update.call(user: @user, operations: [], source: "web") }
  end

  test "a failing operation rolls back the whole batch" do
    assert_no_difference [ "Entry.count", "EntryChange.count" ] do
      assert_raises(Loadouts::Update::Error) do
        update({ op: "add", category: "coding", tool: "cursor" }, { op: "remove", category: "video", tool: "runway" })
      end
    end
  end
end
