# frozen_string_literal: true

require "test_helper"
require "generators/tool/tool_generator"

class ToolGeneratorTest < Rails::Generators::TestCase
  tests ToolGenerator
  destination Rails.root.join("tmp/generators")

  setup do
    prepare_destination
    FileUtils.mkdir_p(File.join(destination_root, "app/tools"))
    FileUtils.cp(Rails.root.join("app/tools/tool_registry.rb"), File.join(destination_root, "app/tools"))
  end

  test "scaffolds the tool, its test, and its registry entry as valid Ruby" do
    run_generator %w[SearchNotes]

    assert_file "app/tools/search_notes_tool.rb" do |content|
      assert_match(/class SearchNotesTool < ApplicationTool/, content)
      assert_match(/tool_name "search_notes"/, content)
      assert_match(/input_schema\(/, content)
    end
    assert_file "test/tools/search_notes_tool_test.rb", /ToolRegistry\.call\("search_notes"/
    assert_file "app/tools/tool_registry.rb" do |content|
      assert_match(/TOOLS = \[\n    SearchNotesTool,\n    WhoamiTool\n  \]/, content)
    end

    %w[app/tools/search_notes_tool.rb test/tools/search_notes_tool_test.rb app/tools/tool_registry.rb].each do |path|
      assert RubyVM::InstructionSequence.compile_file(File.join(destination_root, path))
    end
  end
end
