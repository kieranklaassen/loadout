require "test_helper"

class Agents::CapabilitiesTest < ActiveSupport::TestCase
  def tool_words
    ToolRegistry.tools.flat_map { |tool| tool.tool_name.split(/[_.\-]/) }
  end

  def operation_words
    SuggestPicksTool.input_schema.to_h.dig(:properties, :operations, :items, :properties, :op, :enum).flat_map { |op| op.split("_") }
  end

  test "every line of what an agent can do is backed by tools that exist, and every tool is covered" do
    backing = Agents::Capabilities::CAN.values.flatten

    assert_empty backing - ToolRegistry.tools.map(&:tool_name)
    assert_equal ToolRegistry.tools.map(&:tool_name).sort, backing.sort, "a new tool needs a line the member reads before approving"
  end

  test "every line of what an agent cannot do is backed by the absence of any tool or operation for it (AE7)" do
    Agents::Capabilities::CANNOT.each do |line, words|
      assert words.any?, "#{line} names no tool words"
      assert_empty words & tool_words, "#{line.inspect} but a tool is named #{(words & tool_words).join(", ")}"
      assert_empty words & operation_words, "#{line.inspect} but suggest_picks offers it"
    end
  end

  test "the lines cover the member's decisions: confirming, visibility, the link, deleting" do
    lines = Agents::Capabilities::CANNOT.keys.join(" ")

    assert_match(/confirm/i, lines)
    assert_match(/who can see/i, lines)
    assert_match(/link/i, lines)
    assert_match(/delete/i, lines)
  end

  test "the props carry the lines and the WebMCP session limit" do
    prop = Agents::Capabilities.to_prop

    assert_equal Agents::Capabilities::CAN.keys, prop[:can]
    assert_equal Agents::Capabilities::CANNOT.keys, prop[:cannot]
    assert_match(/signed-in session/, prop[:webmcp_note])
    assert_match(/Confirm/, prop[:webmcp_note])
  end
end
