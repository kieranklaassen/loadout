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

    def call = { source:, client_name: }
  end

  test "source and client_name come from the server context" do
    response = SourceTool.call(server_context: { user: users(:one), source: "mcp", client_name: "Cursor" })
    assert_equal({ "source" => "mcp", "client_name" => "Cursor" }, JSON.parse(text(response)))
  end

  test "a Loadouts::Update::Error becomes an isError result" do
    response = UpdateLoadoutTool.call(operations: [ { op: "nope", category: "coding" } ], server_context: { user: users(:one), source: "mcp" })
    assert response.error?
    assert_match(/Unknown operation/, text(response))
  end
end
