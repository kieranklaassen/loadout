# frozen_string_literal: true

class GetMyLoadoutTool < ApplicationTool
  tool_name "get_my_loadout"
  description <<~TEXT.squish
    Returns the signed-in member's current Loadout: for each category they have filled in,
    the tools they use there, the model they use inside each tool (if any), an optional
    short note, and which entry is their go-to (`primary`). Items marked `pending` were
    added by name and wait for catalog review. Read this before update_loadout so you
    change what is there instead of duplicating it.
  TEXT
  input_schema(properties: {}, required: [], additionalProperties: false)
  annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false)

  def call
    { handle: user.handle, public: user.public?, categories: Loadouts::Presenter.new(user).categories }
  end
end
