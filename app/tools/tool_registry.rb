# frozen_string_literal: true

# The one list of agent tools (docs/modules/webmcp.md). Both surfaces read it:
#
# - MCP clients: `ToolRegistry.mcp_server(user:)` is an MCP::Server for whatever
#   transport the app mounts.
# - WebMCP browser agents: `ToolRegistry.manifest` is the shared Inertia prop the
#   page registers on the browser's model context, and `ToolRegistry.call` runs
#   a registered tool for WebmcpToolsController through that same MCP::Server,
#   so a browser call and an MCP `tools/call` return the identical result.
#
# The list is explicit rather than discovered through `inherited`: Zeitwerk
# loads app/tools lazily in development, so self-registration would miss any
# tool nothing had referenced yet. `bin/rails g tool Name` appends here.
module ToolRegistry
  TOOLS = [
    WhoamiTool
  ].freeze

  # Must match the `webmcp_tool` route in config/routes.rb.
  ENDPOINT = "/webmcp/tools"

  module_function

  def tools
    TOOLS
  end

  def find(name)
    TOOLS.find { |tool| tool.tool_name == name }
  end

  def mcp_server(user:)
    MCP::Server.new(
      name: Rails.application.class.module_parent_name.underscore,
      tools: TOOLS,
      server_context: { user: }
    )
  end

  # Tool definitions for the page, in the MCP `tools/list` shape (`inputSchema`,
  # camelCase annotations) that WebMCP's `registerTool` also takes.
  def manifest
    {
      endpoint: ENDPOINT,
      tools: TOOLS.map { |tool| tool.to_h.slice(:name, :description, :inputSchema, :annotations) }
    }
  end

  # Returns the MCP `CallToolResult` hash (`content`, `isError`), or nil when no
  # tool has that name. Argument validation failures are `isError` results.
  def call(name, arguments:, user:)
    return unless find(name)

    response = mcp_server(user:).handle(
      { jsonrpc: "2.0", id: 1, method: "tools/call", params: { name:, arguments: } }
    )
    response[:result] || error_result(response.dig(:error, :message) || "Tool call failed")
  end

  def error_result(message)
    { content: [ { type: "text", text: message } ], isError: true }
  end
end
