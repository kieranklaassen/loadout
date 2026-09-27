# Inline data for the read-layer tests (test/queries): a person with real rows, so the
# visibility callbacks run, and picks that write their change row the way the write
# path does. Fixture picks are described in test/fixtures/entries.yml.
module ReadLayerHelper
  # team: true makes a verified @every.to address (the Every team); false a non-team one.
  def add_person(handle, visibility: "link", team: false, name: handle.capitalize)
    User.create!(
      email_address: "#{handle}@#{team ? "every.to" : "example.com"}", email_verified: team,
      handle:, name:, visibility:, onboarded_at: Time.current
    )
  end

  # `category`, `tool` and `model` are fixture names or records.
  def add_pick(user, category, rank, tool, model: nil, context: nil, effort: nil)
    category = categories(category) unless category.is_a?(Category)
    tool = tools(tool) unless tool.is_a?(Tool)
    model = ai_models(model) if model.is_a?(Symbol)

    Entry.create!(user:, category:, tool:, ai_model: model, rank:, context:, effort:).tap do
      EntryChange.create!(user:, category:, tool:, ai_model: model, action: "set", source: "web", rank:, context:, effort:)
    end
  end

  # An approved catalog item the fixtures do not have.
  def add_tool(name, status: "approved", **attributes)
    Tool.create!(name:, status:, category_slugs: [], **attributes)
  end

  def add_model(name, status: "approved", **attributes)
    AiModel.create!(name:, status:, category_slugs: [], **attributes)
  end

  # Every hash key anywhere in a nested output, to hold it to its contract.
  def all_keys(value)
    case value
    when Hash then value.flat_map { |key, inner| [ key ] + all_keys(inner) }
    when Array then value.flat_map { |inner| all_keys(inner) }
    else []
    end
  end

  # The fields no read-layer output may carry, whoever the viewer is.
  def assert_no_private_fields(output)
    leaked = all_keys(output) & %i[email_address email bio]
    assert_empty leaked, "output carries #{leaked.join(", ")}"
    assert_no_match(/@(every\.to|example\.com|gmail\.com)/, output.to_json, "an email address is in the output")
  end
end

ActiveSupport.on_load(:active_support_test_case) { include ReadLayerHelper }
