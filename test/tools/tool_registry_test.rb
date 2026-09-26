# frozen_string_literal: true

require "test_helper"

class ToolRegistryTest < ActiveSupport::TestCase
  # WebMCP (Chrome) and MCP share this alphabet; a name outside it is rejected
  # at registration and would fail silently in the browser.
  TOOL_NAME = /\A[A-Za-z0-9_.\-]{1,128}\z/

  setup { @user = users(:one) }

  def mcp(method, params = nil)
    ToolRegistry.mcp_server(user: @user, source: "mcp").handle({ jsonrpc: "2.0", id: 1, method:, params: }.compact)
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

  test "the WebMCP manifest lists the same tools as MCP tools/list" do
    listed = mcp("tools/list")[:result][:tools].map { |tool| tool.slice(:name, :description, :inputSchema, :annotations) }
    assert_equal listed, ToolRegistry.manifest[:tools]
    assert_equal "/webmcp/tools", ToolRegistry.manifest[:endpoint]
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

  test "only the tools that never write are marked read-only" do
    read_only = ToolRegistry.tools.select { |tool| tool.annotations_value.read_only_hint }.map(&:tool_name)
    assert_equal %w[list_categories search_catalog get_my_loadout get_recent_changes], read_only
    assert UpdateLoadoutTool.annotations_value.destructive_hint
  end

  test "the MCP server carries the member, the source, and the client name" do
    server = ToolRegistry.mcp_server(user: @user, source: "mcp", client_name: "Cursor")
    assert_equal({ user: @user, source: "mcp", client_name: "Cursor" }, server.server_context)
  end
end
