# frozen_string_literal: true

# Base class for every agent tool (docs/modules/webmcp.md). A tool is an
# MCP::Tool, so the official SDK's DSL declares it once — `tool_name`,
# `description`, `input_schema`, `annotations` — and ToolRegistry serves the
# same class to MCP clients and to WebMCP browser agents.
#
# Subclasses implement `#call` and return a String or anything JSON-serializable;
# raise ApplicationTool::Error for a failure the agent should read (it becomes
# an `isError` result, never a 500). `user` is the signed-in user the call acts
# as — tools never run without one. `source` ("mcp" or "webmcp") and
# `client_name` (the OAuth client's name over MCP) come from the server context
# and are recorded on every change a tool writes.
class ApplicationTool < MCP::Tool
  class Error < StandardError; end

  def self.call(server_context:, **arguments)
    user = server_context[:user]
    return error_response("Sign in to use #{tool_name}.") unless user

    tool = new(user:, arguments:, source: server_context[:source], client_name: server_context[:client_name])
    text_response(tool.call)
  rescue Error, Loadouts::Update::Error => e
    error_response(e.message)
  end

  def self.text_response(value)
    MCP::Tool::Response.new([ { type: "text", text: value.is_a?(String) ? value : value.to_json } ])
  end

  def self.error_response(message)
    MCP::Tool::Response.new([ { type: "text", text: message } ], error: true)
  end

  attr_reader :user, :arguments, :source, :client_name

  def initialize(user:, arguments:, source: nil, client_name: nil)
    @user = user
    @arguments = arguments
    @source = source
    @client_name = client_name
  end

  def call
    raise NotImplementedError, "#{self.class.name} must implement #call"
  end

  private
    def update_loadout!(operations)
      Loadouts::Update.call(user:, operations:, source:, client_name:)
    end
end
