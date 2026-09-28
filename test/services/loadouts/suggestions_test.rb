require "test_helper"

class Loadouts::SuggestionsTest < ActiveSupport::TestCase
  CHANGED = "This changed, review it.".freeze

  setup do
    @user = users(:one)
    @coding = categories(:coding)
    @windsurf = Tool.create!(name: "Windsurf", status: "approved")
    @zed = Tool.create!(name: "Zed", status: "approved")
  end

  def suggest(tool, category: "coding", source: "mcp", client_name: "Claude", oauth_client_id: 1, **fields)
    Loadouts::Update.call(user: @user, operations: [ { op: "suggest", category:, tool:, **fields } ], source:, client_name:, oauth_client_id:)
  end

  def as_member(*operations)
    Loadouts::Update.call(user: @user, operations:, source: "web")
  end

  def confirm(suggestion, **fields)
    as_member({ op: "confirm", suggestion_id: suggestion.id, **fields })
  end

  def pick(rank, tool, **fields)
    { op: "set_pick", category: "coding", rank:, tool:, **fields }
  end

  def ranked_tools
    @user.entries.order(:rank).map { |entry| [ entry.rank, entry.tool.slug ] }
  end

  def error_from(&block)
    assert_raises(Loadouts::Update::Error, &block).message
  end

  test "suggest keeps entries, readers and loadout_updated_at untouched and records who suggested (AE3)" do
    result = suggest("cursor", model: "claude-opus-5-5", context: "1m", effort: "high", rank: 2)

    suggestion = result.suggestions.sole
    assert_equal [ "open", "Claude", 1, 2, "1m", "high" ], [ suggestion.status, suggestion.client_name, suggestion.oauth_client_id, suggestion.slot_hint, suggestion.context, suggestion.effort ]
    assert_equal [ tools(:cursor), ai_models(:opus_5_5), @coding ], [ suggestion.tool, suggestion.ai_model, suggestion.category ]
    assert_empty result.messages
    assert_empty @user.entries
    assert_nil @user.reload.loadout_updated_at

    change = result.changes.sole
    assert_equal [ "suggested", "mcp", "Claude", suggestion.id ], [ change.action, change.source, change.client_name, change.details["suggestion_id"] ]
    assert_replays_to_entries @user
  end

  test "an agent with no client name is labelled by its transport" do
    assert_equal "WebMCP", suggest("cursor", source: "webmcp", client_name: nil, oauth_client_id: nil).suggestions.sole.client_name
    assert_equal "An agent", suggest("claude-code", source: "mcp", client_name: nil).suggestions.sole.client_name
  end

  test "a rank hint must be 1, 2 or 3" do
    assert_equal "A rank hint must be 1, 2 or 3.", error_from { suggest("cursor", rank: 4) }
    assert_empty @user.pick_suggestions
  end

  test "confirm places the pick at the hinted slot when it is empty, else the first empty slot" do
    confirm(suggest("cursor", rank: 2).suggestions.sole)
    assert_equal [ [ 2, "cursor" ] ], ranked_tools

    confirm(suggest("claude-code", rank: 2).suggestions.sole)
    assert_equal [ [ 1, "claude-code" ], [ 2, "cursor" ] ], ranked_tools

    confirm(suggest("Windsurf").suggestions.sole)
    assert_equal [ [ 1, "claude-code" ], [ 2, "cursor" ], [ 3, "windsurf" ] ], ranked_tools
    assert_replays_to_entries @user
  end

  test "confirm records who suggested, moves loadout_updated_at, and closes the suggestion" do
    suggestion = suggest("cursor", model: "claude-opus-5-5", context: "1m").suggestions.sole

    result = confirm(suggestion)

    change = result.changes.sole
    assert_equal [ "confirmed", "web", nil, 1, "1m" ], [ change.action, change.source, change.client_name, change.rank, change.context ]
    assert_equal({ "suggestion_id" => suggestion.id, "suggested_by" => "Claude" }, change.details.slice("suggestion_id", "suggested_by"))
    assert_equal "confirmed", suggestion.reload.status
    assert_not_nil suggestion.resolved_at
    assert_not_nil @user.reload.loadout_updated_at
    assert_replays_to_entries @user
  end

  test "confirm into an explicit empty slot uses it" do
    confirm(suggest("cursor").suggestions.sole, rank: 3)

    assert_equal [ [ 3, "cursor" ] ], ranked_tools
    assert_replays_to_entries @user
  end

  test "confirm on a full kind without a slot to replace asks which pick and changes nothing" do
    as_member(pick(1, "cursor"), pick(2, "claude-code"), pick(3, "Windsurf"))
    suggestion = suggest("Zed").suggestions.sole
    @user.update_columns(loadout_updated_at: nil)

    assert_no_difference [ "Entry.count", "EntryChange.count" ] do
      assert_equal "All three slots are taken. Choose which pick to replace.", error_from { confirm(suggestion) }
    end
    assert_equal "open", suggestion.reload.status
    assert_nil @user.reload.loadout_updated_at
  end

  test "confirm can replace a chosen pick when the posted snapshot matches it" do
    as_member(pick(1, "cursor", model: "claude-opus-5-5"), pick(2, "claude-code"), pick(3, "Windsurf"))
    suggestion = suggest("Zed").suggestions.sole

    confirm(suggestion, rank: 1, expected: { tool: "cursor", model: "claude-opus-5-5" })

    assert_equal [ [ 1, "zed" ], [ 2, "claude-code" ], [ 3, "windsurf" ] ], ranked_tools
    assert_replays_to_entries @user
  end

  test "confirm never overwrites a pick the person was not shown" do
    as_member(pick(1, "cursor", model: "claude-opus-5-5"), pick(2, "claude-code"), pick(3, "Windsurf"))
    suggestion = suggest("Zed").suggestions.sole

    [ { rank: 1 }, { rank: 1, expected: { tool: "cursor", model: nil } }, { rank: 2, expected: { tool: "cursor", model: "claude-opus-5-5" } } ].each do |fields|
      assert_equal CHANGED, error_from { confirm(suggestion, **fields) }, fields.inspect
    end
    assert_equal [ [ 1, "cursor" ], [ 2, "claude-code" ], [ 3, "windsurf" ] ], ranked_tools
    assert_equal "open", suggestion.reload.status
  end

  test "confirm into a slot that was empty when rendered fails if a pick has arrived since" do
    suggestion = suggest("cursor").suggestions.sole
    as_member(pick(1, "claude-code"))

    assert_equal CHANGED, error_from { confirm(suggestion, rank: 1, expected: nil) }
    assert_equal [ [ 1, "claude-code" ] ], ranked_tools
  end

  test "suggesting a tool already in the kind targets that slot as a change and snapshots what it replaces" do
    as_member(pick(1, "claude-code"), pick(2, "cursor", model: "claude-opus-5-5", context: "200k"))

    suggestion = suggest("cursor", model: "claude-opus-5-5", context: "1m", rank: 3).suggestions.sole

    assert_equal [ 2, tools(:cursor).id, ai_models(:opus_5_5).id ], [ suggestion.replaces_rank, suggestion.replaces_tool_id, suggestion.replaces_ai_model_id ]
    confirm(suggestion)
    entry = @user.entries.find_by!(rank: 2)
    assert_equal [ tools(:cursor), "1m" ], [ entry.tool, entry.context ]
    assert_equal 2, @user.entries.count
    assert_replays_to_entries @user
  end

  test "a suggestion identical to a confirmed pick is a no-op with a message" do
    as_member(pick(1, "cursor", model: "claude-opus-5-5", context: "1m"))

    assert_no_difference [ "PickSuggestion.count", "EntryChange.count" ] do
      result = suggest("cursor", model: "claude-opus-5-5", context: "1m", rank: 3)
      assert_empty result.suggestions
      assert_empty result.changes
      assert_equal [ "Cursor is already your 1st pick for coding with those details." ], result.messages
    end
  end

  test "a change is refused with This changed, review it when the pick moved on since it was suggested" do
    as_member(pick(1, "cursor", model: "claude-opus-5-5"))
    suggestion = suggest("cursor", model: "claude-opus-5-5", context: "1m").suggestions.sole
    as_member({ op: "set_pick", category: "coding", rank: 1, model: "claude-opus-5" })

    assert_equal CHANGED, error_from { confirm(suggestion) }
    assert_equal [ ai_models(:opus_5), nil ], [ @user.entries.sole.ai_model, @user.entries.sole.context ]
    assert_equal "open", suggestion.reload.status
  end

  test "a change is refused when the tool moved to another slot" do
    as_member(pick(1, "cursor"), pick(2, "claude-code"))
    suggestion = suggest("cursor", context: "1m").suggestions.sole
    as_member({ op: "move_pick", category: "coding", rank: 1, direction: "down" })

    assert_equal CHANGED, error_from { confirm(suggestion) }
  end

  test "suggestions that are no longer open cannot be confirmed" do
    superseded = suggest("cursor").suggestions.sole
    suggest("cursor", model: "claude-opus-5-5")
    withdrawn = suggest("claude-code").suggestions.sole
    Loadouts::Update.call(user: @user, operations: [ { op: "withdraw", suggestion_id: withdrawn.id } ], source: "mcp", client_name: "Claude", oauth_client_id: 1)
    dismissed = suggest("Windsurf").suggestions.sole
    as_member({ op: "dismiss", suggestion_id: dismissed.id })
    confirmed = suggest("Zed").suggestions.sole
    confirm(confirmed)

    [ superseded, withdrawn, dismissed, confirmed ].each do |suggestion|
      assert_equal CHANGED, error_from { confirm(suggestion) }, suggestion.status
    end
  end

  test "a member cannot confirm or dismiss another member's suggestion" do
    foreign = pick_suggestions(:ana_runway)

    assert_equal CHANGED, error_from { confirm(foreign) }
    assert_equal "That suggestion is no longer open.", error_from { as_member({ op: "dismiss", suggestion_id: foreign.id }) }
    assert_equal "open", foreign.reload.status
    assert_empty @user.entries
  end

  test "confirming clears other open suggestions that now duplicate the result" do
    chosen = suggest("cursor", model: "claude-opus-5-5", oauth_client_id: 1).suggestions.sole
    duplicate = suggest("cursor", model: "claude-opus-5-5", client_name: "Codex", oauth_client_id: 2).suggestions.sole
    unrelated = suggest("claude-code", oauth_client_id: 1).suggestions.sole

    confirm(chosen)

    assert_equal [ "confirmed", "superseded", "open" ], [ chosen, duplicate, unrelated ].map { |suggestion| suggestion.reload.status }
    assert_equal [ "cursor" ], @user.entries.map { |entry| entry.tool.slug }
  end

  test "confirming also clears a suggestion for the same tool that was written against the old slot" do
    chosen = suggest("cursor", model: "claude-opus-5-5", oauth_client_id: 1).suggestions.sole
    contradicting = suggest("cursor", model: "gpt-6-astra", client_name: "Other", oauth_client_id: 3).suggestions.sole

    confirm(chosen)

    assert_equal [ "confirmed", "superseded" ], [ chosen, contradicting ].map { |suggestion| suggestion.reload.status }
  end

  test "a same-tool suggestion still valid after a confirm stays open" do
    as_member(pick(1, "cursor", model: "claude-opus-5-5"))
    chosen = suggest("cursor", model: "claude-opus-5-5", context: "1m", oauth_client_id: 1).suggestions.sole
    still_valid = suggest("cursor", model: "claude-opus-5-5", effort: "high", client_name: "Codex", oauth_client_id: 2).suggestions.sole

    confirm(chosen)

    assert_equal "open", still_valid.reload.status
    confirm(still_valid)
    entry = @user.entries.sole
    assert_equal [ "1m", "high" ], [ entry.context, entry.effort ], "a field the suggestion leaves blank keeps what the member has"
  end

  test "confirming a change that names only a model keeps the pick's context and effort" do
    as_member(pick(1, "cursor", model: "claude-opus-5", context: "1m", effort: "high"))

    confirm(suggest("cursor", model: "claude-opus-5-5").suggestions.sole)

    entry = @user.entries.sole
    assert_equal [ ai_models(:opus_5_5), "1m", "high" ], [ entry.ai_model, entry.context, entry.effort ]
    assert_replays_to_entries @user
  end

  test "a tool new to the kind keeps its blank fields blank, even when it replaces another pick" do
    as_member(pick(1, "cursor", model: "claude-opus-5-5", context: "1m", effort: "high"), pick(2, "claude-code"), pick(3, "Windsurf"))

    confirm(suggest("Zed", context: "200k").suggestions.sole, rank: 1, expected: { tool: "cursor", model: "claude-opus-5-5" })

    entry = @user.entries.find_by!(rank: 1)
    assert_equal [ "zed", nil, "200k", nil ], [ entry.tool.slug, entry.ai_model, entry.context, entry.effort ]
  end

  test "a suggestion whose named fields all match the pick is a no-op, whatever it leaves blank" do
    as_member(pick(1, "cursor", model: "claude-opus-5-5", context: "1m", effort: "high"))

    assert_no_difference [ "PickSuggestion.count", "EntryChange.count" ] do
      [ { model: "claude-opus-5-5" }, { context: "1m", effort: "high" }, {} ].each do |fields|
        assert_equal [ "Cursor is already your 1st pick for coding with those details." ], suggest("cursor", **fields).messages, fields.inspect
      end
    end
    assert_equal "open", suggest("cursor", effort: "low").suggestions.sole.status
  end

  test "confirming clears a same-tool suggestion that names only what the pick now has" do
    as_member(pick(1, "cursor", model: "claude-opus-5-5"))
    chosen = suggest("cursor", context: "1m", effort: "high", oauth_client_id: 1).suggestions.sole
    now_a_no_op = suggest("cursor", effort: "high", client_name: "Codex", oauth_client_id: 2).suggestions.sole
    still_valid = suggest("cursor", effort: "low", client_name: "Other", oauth_client_id: 3).suggestions.sole

    confirm(chosen)

    assert_equal [ "confirmed", "superseded", "open" ], [ chosen, now_a_no_op, still_valid ].map { |suggestion| suggestion.reload.status }
  end

  test "a newer suggestion from the same client for the same tool supersedes the earlier one, and clients are told apart by id (AE9)" do
    first = suggest("cursor", client_name: "Claude", oauth_client_id: 1).suggestions.sole
    other_client = suggest("cursor", client_name: "Claude", oauth_client_id: 2).suggestions.sole
    assert_equal [ "open", "open" ], [ first, other_client ].map { |suggestion| suggestion.reload.status }

    newer = suggest("cursor", client_name: "Claude", oauth_client_id: 1, model: "claude-opus-5-5").suggestions.sole
    other_tool = suggest("claude-code", client_name: "Claude", oauth_client_id: 1).suggestions.sole

    assert_equal [ "superseded", "open", "open", "open" ], [ first, other_client, newer, other_tool ].map { |suggestion| suggestion.reload.status }
    assert_not_nil first.resolved_at
    assert_equal %w[suggested], @user.entry_changes.distinct.pluck(:action), "supersession writes no change row"
    assert_equal 4, @user.entry_changes.count
  end

  test "a newer suggestion that matches the pick still replaces the same client's older one" do
    as_member(pick(1, "cursor", model: "claude-opus-5-5", context: "1m", effort: "high"))
    wrong = suggest("cursor", effort: "low", oauth_client_id: 1).suggestions.sole
    other_client = suggest("cursor", effort: "low", client_name: "Codex", oauth_client_id: 2).suggestions.sole

    result = suggest("cursor", effort: "high", oauth_client_id: 1)

    assert_equal [ "Cursor is already your 1st pick for coding with those details." ], result.messages
    assert_equal [ "superseded", "open" ], [ wrong, other_client ].map { |suggestion| suggestion.reload.status }
  end

  test "WebMCP is one bucket, separate from every OAuth client" do
    first = suggest("cursor", source: "webmcp", client_name: nil, oauth_client_id: nil).suggestions.sole
    from_client = suggest("cursor", oauth_client_id: 9).suggestions.sole
    second = suggest("cursor", source: "webmcp", client_name: nil, oauth_client_id: nil, model: "claude-opus-5-5").suggestions.sole

    assert_equal [ "superseded", "open", "open" ], [ first, from_client, second ].map { |suggestion| suggestion.reload.status }
  end

  test "at most three suggestions stay open per kind, and the oldest gives way" do
    cursor = suggest("cursor").suggestions.sole
    claude_code = suggest("claude-code").suggestions.sole
    windsurf = suggest("Windsurf").suggestions.sole
    zed = suggest("Zed").suggestions.sole
    video = suggest("runway", category: "video").suggestions.sole

    assert_equal [ "superseded", "open", "open", "open", "open" ], [ cursor, claude_code, windsurf, zed, video ].map { |suggestion| suggestion.reload.status }
    assert_equal 3, @user.pick_suggestions.open.where(category: @coding).count
  end

  test "a dismissed suggestion is refused again for 30 days, but a different one is not" do
    suggestion = suggest("cursor", model: "claude-opus-5-5").suggestions.sole
    result = as_member({ op: "dismiss", suggestion_id: suggestion.id })

    change = result.changes.sole
    assert_equal [ "dismissed", "web", "Claude" ], [ change.action, change.source, change.details["suggested_by"] ]
    assert_equal "dismissed", suggestion.reload.status
    assert_empty @user.entries
    assert_nil @user.reload.loadout_updated_at
    assert_replays_to_entries @user

    message = error_from { suggest("cursor", model: "claude-opus-5-5", client_name: "Codex", oauth_client_id: 2) }
    assert_match(/dismissed on #{Regexp.escape(Date.current.to_fs(:long))}/, message)
    assert_equal "open", suggest("cursor", model: "claude-opus-5", oauth_client_id: 2).suggestions.sole.status
    travel 29.days do
      assert_match(/dismissed on/, error_from { suggest("cursor", model: "claude-opus-5-5") })
    end
    travel 31.days do
      assert_equal "open", suggest("cursor", model: "claude-opus-5-5").suggestions.sole.status
    end
  end

  test "an unconfirmed suggestion lapses after 30 days but its row is kept" do
    suggestion = suggest("cursor").suggestions.sole

    travel 29.days do
      assert_includes PickSuggestion.open, suggestion
    end
    travel 31.days do
      assert_not_includes PickSuggestion.open, suggestion
      assert_equal CHANGED, error_from { confirm(suggestion) }

      suggest("claude-code")
      assert_equal "expired", suggestion.reload.status
    end
    assert PickSuggestion.exists?(suggestion.id)
  end

  test "withdraw closes the same client's own suggestion and no one else's, without a change row" do
    mine = suggest("cursor", oauth_client_id: 1).suggestions.sole
    theirs = suggest("claude-code", client_name: "Codex", oauth_client_id: 2).suggestions.sole
    changes = @user.entry_changes.count

    result = Loadouts::Update.call(user: @user, operations: [ { op: "withdraw", suggestion_id: mine.id } ], source: "mcp", client_name: "Claude", oauth_client_id: 1)

    assert_equal "withdrawn", mine.reload.status
    assert_not_nil mine.resolved_at
    assert_empty result.changes
    assert_equal changes, @user.entry_changes.count
    error = assert_raises(Loadouts::Update::Error) do
      Loadouts::Update.call(user: @user, operations: [ { op: "withdraw", suggestion_id: theirs.id } ], source: "mcp", client_name: "Claude", oauth_client_id: 1)
    end
    assert_equal "That suggestion is no longer open.", error.message
    assert_equal "open", theirs.reload.status
  end

  test "disconnecting a client withdraws only that client's open suggestions (AE9)" do
    claude = OauthClient.create!(client_name: "Claude", redirect_uris: [ "http://127.0.0.1:33418/callback" ])
    other_claude = OauthClient.create!(client_name: "Claude", redirect_uris: [ "http://127.0.0.1:33419/callback" ])
    ours = suggest("cursor", oauth_client_id: claude.id).suggestions.sole
    same_name = suggest("claude-code", oauth_client_id: other_claude.id).suggestions.sole
    web_mcp = suggest("Windsurf", source: "webmcp", client_name: nil, oauth_client_id: nil).suggestions.sole
    someone_else = Loadouts::Update.call(user: users(:two), operations: [ { op: "suggest", category: "coding", tool: "cursor" } ], source: "mcp", client_name: "Claude", oauth_client_id: claude.id).suggestions.sole

    assert_equal 1, Loadouts::Suggestions.withdraw_for_client(user: @user, oauth_client: claude)

    assert_equal [ "withdrawn", "open", "open", "open" ], [ ours, same_name, web_mcp, someone_else ].map { |suggestion| suggestion.reload.status }
  end

  test "revoking a grant withdraws that client's open suggestions" do
    claude = OauthClient.create!(client_name: "Claude", redirect_uris: [ "http://127.0.0.1:33418/callback" ])
    other = OauthClient.create!(client_name: "Claude", redirect_uris: [ "http://127.0.0.1:33419/callback" ])
    ours = suggest("cursor", oauth_client_id: claude.id).suggestions.sole
    theirs = suggest("claude-code", oauth_client_id: other.id).suggestions.sole
    grant = OauthGrant.issue!(user: @user, client: claude, resource: "http://www.example.com/mcp", scope: "loadout")

    grant.revoke!

    assert_equal [ "withdrawn", "open" ], [ ours, theirs ].map { |suggestion| suggestion.reload.status }
    assert_not_nil grant.reload.revoked_at
  end

  test "suggestion rows never show up in Entry queries" do
    suggest("cursor")
    suggest("claude-code", category: "video")

    assert_equal 2, @user.pick_suggestions.count
    assert_equal 0, Entry.where(user: @user).count
  end
end
