require "test_helper"

class EntryChangeTest < ActiveSupport::TestCase
  setup { @user = users(:one) }

  def update(*operations)
    Loadouts::Update.call(user: @user, operations:, source: "mcp", client_name: "Claude Code")
  end

  def story
    EntryChange.story(@user.entry_changes.recent_first).map { |item| item[:sentence] }
  end

  test "AE2: a model switch in one batch reads as one switch" do
    update({ op: "add", category: "coding", tool: "cursor", model: "claude-opus-5" })
    update({ op: "replace_category", category: "coding", picks: [ { tool: "cursor", model: "claude-opus-5-5" } ] })

    assert_equal [ "added", "removed" ], @user.entry_changes.recent_first.limit(2).map(&:action).sort
    assert_equal "Switched coding model from Claude Opus 5 to Claude Opus 5.5 in Cursor", story.first
  end

  test "a tool switch in one batch reads as a switch between tools" do
    update({ op: "add", category: "coding", tool: "cursor" })
    update({ op: "replace_category", category: "coding", picks: [ { tool: "claude-code", model: "claude-opus-5-5" } ] })

    assert_equal "Switched coding from Cursor to Claude Code with Claude Opus 5.5", story.first
  end

  test "additions, removals, notes, and go-to changes read plainly" do
    update({ op: "add", category: "coding", tool: "cursor", primary: true })
    update({ op: "add", category: "coding", tool: "claude-code" })
    update({ op: "set_primary", category: "coding", tool: "claude-code" })
    update({ op: "update_note", category: "coding", tool: "claude-code", note: "Plans first" })
    update({ op: "remove", category: "coding", tool: "cursor" })

    assert_equal [
      "Stopped using Cursor for coding",
      "Updated the note on Claude Code for coding",
      "Made Claude Code the go-to for coding",
      "Added Claude Code for coding",
      "Added Cursor for coding"
    ], story
  end

  test "removing and re-adding the same pick in one batch tells no story" do
    update({ op: "add", category: "coding", tool: "cursor", model: "claude-opus-5" })
    update({ op: "remove", category: "coding", tool: "cursor", model: "claude-opus-5" },
      { op: "add", category: "coding", tool: "cursor", model: "claude-opus-5" })

    assert_equal [ "Added Cursor with Claude Opus 5 for coding" ], story
  end
end
