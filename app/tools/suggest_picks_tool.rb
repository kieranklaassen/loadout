# frozen_string_literal: true

# The only tool that writes, and it writes suggestions: a PickSuggestion is invisible to
# everyone but its owner until the owner confirms it on the web. Nothing here can confirm,
# remove or reorder a pick; the schema only knows Toolbox::Update::AGENT_OPERATIONS.
class SuggestPicksTool < ApplicationTool
  tool_name "suggest_picks"
  description <<~TEXT.squish
    Proposes picks for the signed-in member's Toolbox. Everything you send is a suggestion:
    it is hidden from everyone else and does not appear on the member's page until the member
    confirms it on the site. You cannot confirm, change, remove or reorder their picks.
    A pick is a tool (the app, like Cursor) with an optional model (like Claude Opus 5.5),
    an optional context size and an optional effort; send only what the member told you.
    For a tool the member already has in that kind, a field you leave out keeps the member's
    current value. Send `operations`, applied in order: `suggest` (category, tool, optional model, context,
    effort and a `rank` hint from 1 to 3 for where it belongs) and `withdraw` (suggestion_id
    of one of your own suggestions). `category` is a slug from list_categories; `tool` and
    `model` are slugs from search_catalog (a name that is not in the catalog becomes a new
    item flagged for review, so check spelling first). A member ranks up to three picks
    per kind of work and a tool appears once per kind. Read get_my_toolbox first so you
    suggest a change instead of a duplicate, ask the member before you guess, and do not
    suggest again something they dismissed: the error says when. A kind holds at most three
    open suggestions (the oldest gives way), and a newer one from you for the same tool
    replaces your older one. Returns what was suggested and where the member confirms it.
  TEXT
  input_schema(
    properties: {
      operations: {
        type: "array",
        minItems: 1,
        maxItems: Toolbox::Update::MAX_OPERATIONS,
        items: {
          type: "object",
          properties: {
            op: { type: "string", enum: Toolbox::Update::AGENT_OPERATIONS },
            category: { type: "string", maxLength: 60, description: "For suggest: the kind of work, a slug from list_categories." },
            tool: { type: "string", maxLength: 60, description: "For suggest: tool slug from search_catalog (preferred) or its name." },
            model: { type: [ "string", "null" ], maxLength: 60, description: "For suggest: model slug from search_catalog (preferred) or its name. Omit when the member names no model." },
            context: { type: [ "string", "null" ], enum: [ *Entry::CONTEXTS, nil ], description: "For suggest: the context size the member uses. Omit when unknown." },
            effort: { type: [ "string", "null" ], enum: [ *Entry::EFFORTS, nil ], description: "For suggest: the effort level the member uses. Omit when unknown." },
            rank: { type: [ "integer", "null" ], minimum: 1, maximum: Entry::MAX_RANK, description: "For suggest: which pick this should be, 1 to #{Entry::MAX_RANK}. A hint; the member decides." },
            suggestion_id: { type: "integer", description: "For withdraw: the id of your own open suggestion." }
          },
          required: [ "op" ],
          additionalProperties: false
        }
      }
    },
    required: [ "operations" ],
    additionalProperties: false
  )
  annotations(read_only_hint: false, destructive_hint: false, idempotent_hint: false, open_world_hint: false)

  def call
    result = run_operations!(arguments[:operations])
    # A suggestion a later operation of the same call superseded is neither proposed nor withdrawn.
    proposed = result.suggestions.select { |suggestion| suggestion.status == "open" }
    withdrawn = result.suggestions.select { |suggestion| suggestion.status == "withdrawn" }

    {
      message: message(proposed, withdrawn, result.messages),
      suggestions: proposed.map { |suggestion| suggestion_prop(suggestion) },
      withdrawn: withdrawn.map(&:id)
    }
  end

  private
    def message(proposed, withdrawn, notes)
      sentences = []
      if proposed.any?
        links = proposed.map { |suggestion| link_to(:edit_toolbox_path, kind: suggestion.category.slug) }.uniq.to_sentence
        sentences << "Suggested #{proposed.size} #{"pick".pluralize(proposed.size)}. Nothing is on the member's page yet: each stays a suggestion until the member confirms it on the site (#{links})."
      end
      sentences << "Withdrew #{withdrawn.size} #{"suggestion".pluralize(withdrawn.size)}." if withdrawn.any?
      (sentences + notes).join(" ").presence || "Nothing changed."
    end

    def suggestion_prop(suggestion)
      {
        id: suggestion.id,
        category: suggestion.category.slug,
        tool: suggestion.tool.slug,
        model: suggestion.ai_model&.slug,
        context: suggestion.context,
        effort: suggestion.effort,
        rank_hint: suggestion.slot_hint
      }
    end
end
