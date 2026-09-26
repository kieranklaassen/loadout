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

  test "WhoamiTool returns the signed-in user's email" do
    response = WhoamiTool.call(server_context: @context)
    assert_equal({ "email_address" => "one@example.com" }, JSON.parse(text(response)))
    assert WhoamiTool.annotations_value.read_only_hint
  end
end
