# frozen_string_literal: true

class GetRecentChangesTool < ApplicationTool
  tool_name "get_recent_changes"
  description <<~TEXT.squish
    Returns the member's most recent Loadout changes, newest first, as plain sentences
    ("Switched coding model from Claude Opus 5 to Claude Opus 5.5 in Cursor") with the
    date, the action, and where the change came from (`web`, `mcp` with the agent's
    `client_name`, or `webmcp`). Use it to summarize what changed lately or to confirm
    your own update landed.
  TEXT
  input_schema(
    properties: {
      limit: { type: "integer", minimum: 1, maximum: 50, description: "How many changes to return (default 12)." }
    },
    required: [],
    additionalProperties: false
  )
  annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false)

  def call
    { changes: Loadouts::Presenter.new(user).recent_changes(limit: arguments.fetch(:limit, 12)) }
  end
end
