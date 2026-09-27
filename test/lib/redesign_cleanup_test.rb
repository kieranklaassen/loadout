require "test_helper"

# The Every Loadout redesign retired a model: the members-only map, a go-to and a note on
# every pick, a public flag, visibility checks scattered through the code, and a host
# written out in place. These greps keep those names from coming back. Each rule searches
# the shipped source and lists, by path prefix, the few places allowed to say it; the
# examples prove the pattern fires, so a rule cannot pass just because it stopped working.
class RedesignCleanupTest < ActiveSupport::TestCase
  ROOTS = %w[app lib db/seeds.rb db/seeds config/initializers].freeze
  EXTENSIONS = %w[.rb .erb .rake .ts .tsx .css .js .tt .yml].freeze
  TEST_SOURCE = %r{\.test\.tsx?\z|\Aapp/frontend/test/}

  LEVEL = /["'](?:only_me|team|link)["']/
  COMPARE = /(?:==|!=|===|!==)/

  Rule = Struct.new(:pattern, :fires_on, :quiet_on, :allow, :ruby_only, :skip_tests, keyword_init: true) do
    def applies_to?(path)
      return false if allow&.any? { |prefix| path.start_with?(prefix) }
      return false if ruby_only && !path.end_with?(".rb", ".erb", ".rake")

      !(skip_tests && path.match?(TEST_SOURCE))
    end
  end

  RULES = {
    "the Every map" => Rule.new(
      pattern: /\b(?:MapStats|MapsController|public_map)\b/,
      fires_on: [ "MapStats.new(user)", "class MapsController", "Flipper.enabled?(:public_map)" ],
      quiet_on: [ "TeamRankings", "the map function" ]
    ),
    "the update_loadout tool" => Rule.new(
      pattern: /update_loadout/,
      fires_on: [ "ToolRegistry.find('update_loadout')", "update_loadout!(operations)" ],
      quiet_on: [ "run_operations!(operations)", "Loadouts::Update" ]
    ),
    "the picks.ts module" => Rule.new(
      pattern: %r{\bpicks\.ts\b|lib/picks['"]},
      fires_on: [ "see lib/picks.ts", "import { hasTool } from '../lib/picks'" ],
      quiet_on: [ "import { rankLabel } from '../lib/rank_label'", "const picks = kinds.picks" ]
    ),
    "a go-to on an entry" => Rule.new(
      pattern: /\.primary\b|(?<![\w-])primary:[ \t]*+(?!['"])/,
      fires_on: [ "entry.primary", "entries.where(primary: true)", "{ tool, model, primary: false }", "primary: boolean" ],
      quiet_on: [ "  primary: 'bg-sky text-on-light',", "buttonClasses('primary')", "variant: 'primary'" ]
    ),
    "the users.public flag" => Rule.new(
      pattern: /\bpublic\?|\bpublicly_visible\b/,
      fires_on: [ "user.public?", "User.publicly_visible", "public?: boolean" ],
      quiet_on: [ "expires_in 0.seconds, public: false", "public_host", "visible_to?(nil)" ]
    ),
    "the host written out" => Rule.new(
      pattern: %r{loadout\.every\.to|every\.to/loadout},
      fires_on: [ %(HOST = "loadout.every.to"), "https://every.to/loadout/dan" ],
      quiet_on: [ "LoadoutHost.host", "https://every.to/join", "https://checks.every.to/opus" ],
      allow: %w[app/models/loadout_host.rb app/frontend/lib/public_host.ts],
      skip_tests: true
    ),
    "a visibility value compared outside User::Visibility" => Rule.new(
      pattern: /\.visibility\s*#{COMPARE}|\bwhere(?:\.not)?\([^)]*\bvisibility:/,
      fires_on: [ %(user.visibility == "link"), %(other.visibility != user.visibility), %(User.where(visibility: "link")), %(User.where.not(visibility: "only_me")) ],
      quiet_on: [ %(User.new(visibility: "team")), "user.visible_to?(viewer)", %(show == "team") ],
      allow: %w[app/models/user/visibility.rb db/seeds],
      ruby_only: true,
      skip_tests: true
    ),
    "a visibility value compared to a literal" => Rule.new(
      pattern: /^(?=.*\b(?:visibility|levels?)\b).*(?:#{COMPARE}\s*#{LEVEL}|#{LEVEL}\s*#{COMPARE})/,
      fires_on: [ %(period.level == "link"), %(if visibility != "only_me"), %(current_user?.visibility === 'link'), %("team" == visibility) ],
      quiet_on: [ %(show == "team"), "values.visibility !== account.visibility", %(SHARING_LEVELS = %w[team link].freeze) ],
      # The Home note for a member who shares with anyone with the link.
      allow: %w[app/models/user/visibility.rb db/seeds app/frontend/pages/home/index.tsx],
      skip_tests: true
    )
  }.freeze

  def source_files
    ROOTS.flat_map { |root| File.directory?(Rails.root.join(root)) ? Dir[Rails.root.join(root, "**/*")] : [ Rails.root.join(root).to_s ] }
      .select { |path| File.file?(path) && EXTENSIONS.include?(File.extname(path)) }
      .map { |path| Pathname.new(path).relative_path_from(Rails.root).to_s }
      .sort
  end

  test "each rule fires on what it forbids and stays quiet on what only looks alike" do
    RULES.each do |name, rule|
      rule.fires_on.each { |line| assert_match rule.pattern, line, "#{name}: should fire on #{line.inspect}" }
      rule.quiet_on.each { |line| assert_no_match rule.pattern, line, "#{name}: should stay quiet on #{line.inspect}" }
    end
  end

  test "the shipped source still says none of what the redesign retired" do
    files = source_files
    assert_operator files.size, :>, 100, "the search found too few files to mean anything"

    offenders = RULES.flat_map do |name, rule|
      files.select { |path| rule.applies_to?(path) }.flat_map do |path|
        File.readlines(Rails.root.join(path), chomp: true).each_with_index.filter_map do |line, index|
          "#{name}: #{path}:#{index + 1}: #{line.strip}" if line.match?(rule.pattern)
        end
      end
    end

    assert_empty offenders, "The redesign retired these:\n#{offenders.join("\n")}"
  end

  test "the allowlists name paths that exist" do
    RULES.each do |name, rule|
      Array(rule.allow).each do |prefix|
        assert Dir[Rails.root.join("#{prefix}*")].any?, "#{name}: #{prefix} is allowed but does not exist"
      end
    end
  end

  test "the retired files are gone" do
    assert_empty Dir[Rails.root.join("app/frontend/**/picks.{ts,test.ts}")]
    assert_empty Dir[Rails.root.join("app/frontend/pages/map*")]
    assert_not Rails.root.join("app/controllers/maps_controller.rb").exist?
  end

  test "the catalog has no other kind, in the kinds or on any item" do
    catalog = YAML.safe_load_file(Rails.root.join("config/catalog.yml"), permitted_classes: [ Date ])
    items = catalog.values_at("tools", "models").flatten

    assert_not_includes catalog.fetch("categories").pluck("slug"), "other"
    assert_operator items.size, :>, 10
    assert_empty items.select { |item| Array(item["categories"]).include?("other") }.pluck("slug")
  end
end
