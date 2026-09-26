require "test_helper"

class AgentConventionsTest < ActiveSupport::TestCase
  ROOT = Rails.root
  MANIFEST_MODULES = YAML.load_file(ROOT.join(".template-manifest.yml"))
    .fetch("modules")
    .keys
    .freeze

  test "CLAUDE.md is a symlink resolving to AGENTS.md" do
    claude = ROOT.join("CLAUDE.md")
    assert File.symlink?(claude), "CLAUDE.md must be a symlink to AGENTS.md, not a copy"
    assert_equal "AGENTS.md", File.readlink(claude)
    assert_equal File.read(ROOT.join("AGENTS.md")), File.read(claude)
  end

  test "AGENTS.md carries the standardized sections" do
    agents = File.read(ROOT.join("AGENTS.md"))
    assert_match(/never commit or push to `main`/i, agents)
    assert_match(/^## Local development/, agents)
    assert_match(/^## Deploying/, agents)
  end

  test "AGENTS.md enumerates every manifest module" do
    agents = File.read(ROOT.join("AGENTS.md"))
    enumeration = agents.match(
      %r{one doc per adoptable module \((?<modules>.*?)\), each}m
    )&.[](:modules)
    assert enumeration, "AGENTS.md must contain the adoptable-module enumeration"

    documented_modules = enumeration.split(",").map(&:strip)

    MANIFEST_MODULES.each do |module_name|
      assert_includes documented_modules, module_name,
        "AGENTS.md must enumerate manifest module #{module_name.inspect}"
    end
  end
end
