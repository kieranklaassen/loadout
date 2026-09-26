# frozen_string_literal: true

require "test_helper"

class ToolRegistryTest < ActiveSupport::TestCase
  # WebMCP (Chrome) and MCP share this alphabet; a name outside it is rejected
  # at registration and would fail silently in the browser.
  TOOL_NAME = /\A[A-Za-z0-9_.\-]{1,128}\z/

  setup { @user = users(:one) }

  def mcp(method, params = nil)
    ToolRegistry.mcp_server(user: @user).handle({ jsonrpc: "2.0", id: 1, method:, params: }.compact)
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
    expected = mcp("tools/call", { name: "whoami", arguments: {} })[:result]
    assert_equal expected, ToolRegistry.call("whoami", arguments: {}, user: @user)
  end

  test "call returns nil for an unknown tool" do
    assert_nil ToolRegistry.call("nope", arguments: {}, user: @user)
  end

  test "a tool never runs without a user" do
    result = ToolRegistry.call("whoami", arguments: {}, user: nil)
    assert result[:isError]
    assert_match(/sign in/i, result[:content].first[:text])
  end
end
