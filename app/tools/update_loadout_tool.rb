# frozen_string_literal: true

class UpdateLoadoutTool < ApplicationTool
  PICK_PROPERTIES = {
    tool: { type: "string", maxLength: 60, description: "Tool slug from search_catalog (preferred) or its name." },
    model: { type: [ "string", "null" ], maxLength: 60, description: "Model slug from search_catalog (preferred) or its name. Omit when the member uses no specific model." },
    note: { type: [ "string", "null" ], maxLength: 280, description: "Optional short note in the member's words on why they use it." },
    primary: { type: "boolean", description: "Make this the member's go-to for the category." }
  }.freeze

  tool_name "update_loadout"
  description <<~TEXT.squish
    Changes the signed-in member's Loadout and returns the updated loadout plus one
    sentence per change it made. Send `operations`, applied in order in one transaction:
    `add` (category, tool, optional model, note, primary), `remove` (category, tool, model),
    `set_primary` (category, tool, model), `update_note` (category, tool, model, note), and
    `replace_category` (category, picks: the complete list for that category; anything not
    listed is removed). Categories are slugs from list_categories (coding, knowledge-work,
    writing, research, classification, image, video, animation, text-to-speech,
    speech-to-text, music, other). Etiquette: ask the member before you guess, and only
    record what they confirm; read get_my_loadout first; prefer catalog slugs from
    search_catalog. A tool or model name that is not in the catalog is added as a new
    item flagged for review and shows on the member's profile right away, so check
    spelling first. Visibility and account settings are web-only.
  TEXT
  input_schema(
    properties: {
      operations: {
        type: "array",
        minItems: 1,
        maxItems: Loadouts::Update::MAX_OPERATIONS,
        items: {
          type: "object",
          properties: {
            op: { type: "string", enum: Loadouts::Update::OPERATIONS },
            category: { type: "string", maxLength: 60, description: "Category slug, e.g. \"coding\"." },
            **PICK_PROPERTIES,
            picks: {
              type: "array",
              maxItems: 20,
              description: "For replace_category: every pick the member uses in this category.",
              items: { type: "object", properties: PICK_PROPERTIES, required: [ "tool" ], additionalProperties: false }
            }
          },
          required: %w[op category],
          additionalProperties: false
        }
      }
    },
    required: [ "operations" ],
    additionalProperties: false
  )
  annotations(read_only_hint: false, destructive_hint: true, idempotent_hint: false, open_world_hint: false)

  def call
    result = update_loadout!(arguments[:operations])
    {
      changes: EntryChange.story(result.changes).map { |change| change[:sentence] },
      categories: Loadouts::Presenter.new(user).categories
    }
  end
end
