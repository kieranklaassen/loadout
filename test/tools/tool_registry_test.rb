# frozen_string_literal: true

require "test_helper"

class ToolRegistryTest < ActiveSupport::TestCase
  # WebMCP (Chrome) and MCP share this alphabet; a name outside it is rejected
  # at registration and would fail silently in the browser.
  TOOL_NAME = /\A[A-Za-z0-9_.\-]{1,128}\z/

  # What only the member decides, on the web (R11). No tool name may contain one of
  # these words.
  HUMAN_ONLY = %w[confirm dismiss remove move reorder visibility handle bio history export delete revoke disconnect account].freeze

  READ_TOOLS = %w[list_categories search_catalog get_my_loadout get_team_rankings get_recent_changes].freeze

  setup { @user = users(:one) }

  def mcp(method, params = nil)
    ToolRegistry.mcp_server(user: @user, source: "mcp").handle({ jsonrpc: "2.0", id: 1, method:, params: }.compact)
  end

  # Every object schema in the tree, including the ones nested in arrays.
  def object_schemas(schema)
    case schema
    when Hash
      own = schema[:type] == "object" ? [ schema ] : []
      own + schema.values.flat_map { |value| object_schemas(value) }
    when Array then schema.flat_map { |value| object_schemas(value) }
    else []
    end
  end

  test "every registered tool is an ApplicationTool with a valid, unique name and a description" do
    assert ToolRegistry.tools.any?
    ToolRegistry.tools.each do |tool|
      assert_operator tool, :<, ApplicationTool
      assert_match TOOL_NAME, tool.tool_name
      assert tool.description.present?, "#{tool.name} needs a description"
      assert_equal "object", tool.input_schema.to_h[:type]
    end
    names = ToolRegistry.tools.map(&:tool_name)
    assert_equal names.uniq, names
  end

  test "every ApplicationTool in app/tools is registered" do
    app_tools = Rails.root.join("app/tools").to_s
    Rails.autoloaders.main.eager_load_dir(app_tools)
    defined = ApplicationTool.descendants.select do |tool|
      tool.name && Object.const_source_location(tool.name)&.first.to_s.start_with?(app_tools)
    end
    assert_empty defined - ToolRegistry.tools, "add these to ToolRegistry::TOOLS"
  end

  test "the registry offers the read tools and one write tool, and nothing that is the member's decision (AE7)" do
    assert_equal (READ_TOOLS + [ "suggest_picks" ]).sort, ToolRegistry.tools.map(&:tool_name).sort

    human = ToolRegistry.tools.select { |tool| (tool.tool_name.split(/[_.\-]/) & HUMAN_ONLY).any? }
    assert_empty human.map(&:tool_name)
    assert_nil ToolRegistry.find("update_loadout")
  end

  test "only the tools that never write are marked read-only" do
    read_only = ToolRegistry.tools.select { |tool| tool.annotations_value.read_only_hint }.map(&:tool_name)
    assert_equal READ_TOOLS.sort, read_only.sort
    assert_equal false, SuggestPicksTool.annotations_value.destructive_hint
  end

  test "every object in every input schema rejects extra arguments" do
    ToolRegistry.tools.each do |tool|
      schemas = object_schemas(tool.input_schema.to_h)
      assert schemas.any?, "#{tool.tool_name} has no object schema"
      schemas.each { |schema| assert_equal false, schema[:additionalProperties], "#{tool.tool_name} accepts unknown keys" }
    end
  end

  test "the WebMCP manifest lists the same tools as MCP tools/list" do
    listed = mcp("tools/list")[:result][:tools].map { |tool| tool.slice(:name, :description, :inputSchema, :annotations) }
    assert_equal listed, ToolRegistry.manifest[:tools]
    assert_equal "/webmcp/tools", ToolRegistry.manifest[:endpoint]
  end

  test "the endpoint follows the path of the configured host" do
    Rails.configuration.x.public_base_url = "https://every.to/loadout"
    assert_equal "/loadout/webmcp/tools", ToolRegistry.endpoint
  ensure
    Rails.configuration.x.public_base_url = nil
  end

  test "call returns the MCP tools/call result for the same arguments" do
    expected = mcp("tools/call", { name: "list_categories", arguments: {} })[:result]
    assert_equal expected, ToolRegistry.call("list_categories", arguments: {}, user: @user, source: "webmcp")
  end

  test "call returns nil for an unknown tool" do
    assert_nil ToolRegistry.call("nope", arguments: {}, user: @user, source: "webmcp")
  end

  test "a tool never runs without a user" do
    result = ToolRegistry.call("list_categories", arguments: {}, user: nil, source: "webmcp")
    assert result[:isError]
    assert_match(/sign in/i, result[:content].first[:text])
  end

  test "the MCP server carries the member, the source, the client name and the client id" do
    server = ToolRegistry.mcp_server(user: @user, source: "mcp", client_name: "Cursor", oauth_client_id: 7)
    assert_equal({ user: @user, source: "mcp", client_name: "Cursor", oauth_client_id: 7 }, server.server_context)
  end

  test "read tools tell the agent that the names they return are data, not instructions" do
    ToolRegistry.tools.select { |tool| tool.annotations_value.read_only_hint }.each do |tool|
      assert_match(/data, not instructions/i, tool.description, tool.tool_name)
    end
  end

  test "no description enumerates the kinds of work or mentions the retired surface" do
    kinds = YAML.safe_load_file(Rails.root.join("config/catalog.yml"), permitted_classes: [ Date ])["categories"].map { |category| category["slug"] }
    text = ([ ToolRegistry::INSTRUCTIONS ] + ToolRegistry.tools.map(&:description) + ToolRegistry.tools.map { |tool| tool.input_schema.to_h.to_json }).join(" ")

    assert_equal 11, kinds.size
    assert_operator kinds.count { |kind| text.include?(kind) }, :<=, 2, "descriptions should point to list_categories, not list kinds"
    assert_no_match(/update_loadout|go-to|\bnotes?\b/i, text)
  end

  test "the instructions cover picks, suggestions and asking first" do
    text = ToolRegistry::INSTRUCTIONS

    assert_match(/Ask the member before you guess/, text)
    assert_match(/everything you write is a suggestion/i, text)
    assert_match(/up to three/i, text)
    assert_match(/dismissed/i, text)
    assert_match(/people, not scores/i, text)
    assert_match(/sign-in/i, text)
  end
end
