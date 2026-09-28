# frozen_string_literal: true

class GetMyToolboxTool < ApplicationTool
  tool_name "get_my_toolbox"
  description <<~TEXT.squish
    Returns the signed-in member's Toolbox, kind of work by kind of work: up to three
    confirmed picks ranked 1 to 3 (a tool, the model they use in it if any, a context size
    and an effort if they set them), and their open suggestions, including yours, which
    wait for the member to confirm them on the site and are visible to nobody else.
    `to_confirm` counts the suggestions still waiting. `visibility` (only_me, team or link)
    says who can open the member's page; it is read-only here and the member changes it on
    the site. Items marked `pending` were added by name and wait for catalog review. Read
    this before suggest_picks so you suggest a change instead of a duplicate. #{DATA_NOTICE}
  TEXT
  input_schema(properties: {}, required: [], additionalProperties: false)
  annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false)

  def call
    kinds = Toolbox::Presenter.new(user).kinds
    {
      handle: user.handle,
      visibility: user.visibility,
      url: (link_to(:profile_path, user.handle) if user.handle),
      confirm_at: link_to(:edit_toolbox_path),
      to_confirm: kinds.sum { |kind| kind[:to_confirm] },
      kinds: kinds.map { |kind| kind_prop(kind) }
    }
  end

  private
    def kind_prop(kind)
      kind[:category].slice(:slug, :name).merge(
        picks: kind[:picks].map { |pick| pick_prop(pick) },
        suggestions: kind[:suggestions].map { |suggestion| suggestion_prop(suggestion) },
        to_confirm: kind[:to_confirm]
      )
    end

    def pick_prop(pick)
      pick.merge(tool: item_prop(pick[:tool]), model: item_prop(pick[:model]))
    end

    def suggestion_prop(suggestion)
      {
        id: suggestion[:id],
        tool: item_prop(suggestion[:tool]),
        model: item_prop(suggestion[:model]),
        context: suggestion[:context],
        effort: suggestion[:effort],
        rank_hint: suggestion[:slot_hint],
        replaces: suggestion[:replaces]&.then { |replaced| replaced.merge(tool: item_prop(replaced[:tool]), model: item_prop(replaced[:model])) },
        suggested_by: clean(suggestion[:suggested_by]),
        suggested_at: suggestion[:suggested_at]
      }
    end

    def item_prop(item)
      item&.slice(:slug, :name, :pending)
    end
end
