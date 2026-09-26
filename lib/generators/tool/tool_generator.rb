# frozen_string_literal: true

# `bin/rails g tool SearchNotes` — scaffolds an agent tool served to MCP clients
# and WebMCP browser agents (docs/modules/webmcp.md): the ApplicationTool
# subclass, its test, and its entry in ToolRegistry::TOOLS.
class ToolGenerator < Rails::Generators::NamedBase
  source_root File.expand_path("templates", __dir__)

  def create_tool
    template "tool.rb.tt", File.join("app/tools", class_path, "#{file_name}_tool.rb")
  end

  def create_test
    template "tool_test.rb.tt", File.join("test/tools", class_path, "#{file_name}_tool_test.rb")
  end

  def register_tool
    inject_into_file "app/tools/tool_registry.rb", "    #{class_name}Tool,\n", after: "TOOLS = [\n"
  end

  private
    def tool_name
      file_path.tr("/", "_")
    end
end
