# frozen_string_literal: true

require "test_helper"

class ApplicationToolTest < ActiveSupport::TestCase
  class EchoTool < ApplicationTool
    tool_name "test_echo"
    description "Echoes text back."
    input_schema(properties: { text: { type: "string" } }, required: [ "text" ], additionalProperties: false)

    def call
      raise Error, "Nothing to echo." if arguments[:text].blank?

      arguments[:text] == "json" ? { echoed: user.email_address } : arguments[:text]
    end
  end

  setup { @context = { user: users(:one) } }

  def text(response) = response.to_h[:content].first[:text]

  test "a String result is returned verbatim" do
    assert_equal "hi", text(EchoTool.call(text: "hi", server_context: @context))
  end

  test "any other result is serialized as JSON" do
    assert_equal({ "echoed" => "one@example.com" }, JSON.parse(text(EchoTool.call(text: "json", server_context: @context))))
  end

  test "ApplicationTool::Error becomes an isError result, not an exception" do
    response = EchoTool.call(text: " ", server_context: @context)
    assert response.error?
    assert_equal "Nothing to echo.", text(response)
  end

  test "without a user the tool refuses before running" do
    response = EchoTool.call(text: "hi", server_context: { user: nil })
    assert response.error?
  end

  class SourceTool < ApplicationTool
    tool_name "test_source"
    description "Reports where the call came from."
    input_schema(properties: {}, required: [], additionalProperties: false)

    def call = { source:, client_name:, oauth_client_id: }
  end

  test "source, client_name and oauth_client_id come from the server context" do
    response = SourceTool.call(server_context: { user: users(:one), source: "mcp", client_name: "Cursor", oauth_client_id: 12 })
    assert_equal({ "source" => "mcp", "client_name" => "Cursor", "oauth_client_id" => 12 }, JSON.parse(text(response)))
  end

  class WriteTool < ApplicationTool
    tool_name "test_write"
    description "Sends operations to the write path."
    input_schema(properties: { op: { type: "string" } }, required: [ "op" ], additionalProperties: false)

    def call = run_operations!([ { op: arguments[:op], category: "video", tool: "runway" } ]).suggestions.size
  end

  test "run_operations! writes as the call's source, client name and client id" do
    user = users(:every_dee)
    WriteTool.call(op: "suggest", server_context: { user:, source: "mcp", client_name: "Cursor", oauth_client_id: 12 })

    suggestion = user.pick_suggestions.open.sole
    assert_equal [ "Cursor", 12 ], [ suggestion.client_name, suggestion.oauth_client_id ]
  end

  test "a Toolbox::Update::Error becomes an isError result" do
    response = WriteTool.call(op: "nope", server_context: { user: users(:one), source: "mcp" })
    assert response.error?
    assert_match(/Unknown operation/, text(response))
  end

  test "a decision that belongs to the member is refused for an agent's source" do
    response = WriteTool.call(op: "set_pick", server_context: { user: users(:one), source: "webmcp" })
    assert response.error?
    assert_match(/only be done by the member on the web/, text(response))
  end
end
