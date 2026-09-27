require "test_helper"

# Opus 5.5 is the one launched fixture model (dated 20 days ago, with a checks.every.to
# link). Opus 5 has a date only and GPT-6 neither. For a team viewer (dee) the team is
# ana and dee, who both use Opus 5.5 (ana in coding and knowledge work), so 2 of 2.
class ModelLaunchesTest < ActiveSupport::TestCase
  setup { @dee = users(:every_dee) }

  def opus = ai_models(:opus_5_5)
  def launches(viewer = @dee, **options) = ModelLaunches.new(viewer:, **options).list

  test "AE5: a model lists only with both a release date and a valid Vibe Check link" do
    assert_equal [ opus.slug ], launches.map { |launch| launch[:model][:slug] }, "opus_5 has a date only, gpt_6 neither"

    with_link_only = add_model("Linked Only", vibe_check_url: "https://every.to/vibe-checks/linked")
    with_date_only = add_model("Dated Only", released_on: 3.days.ago.to_date)
    assert_not_includes launches.map { |launch| launch[:model][:slug] }, with_link_only.slug
    assert_not_includes launches.map { |launch| launch[:model][:slug] }, with_date_only.slug

    with_date_only.update!(vibe_check_url: "https://every.to/vibe-checks/dated")
    assert_includes launches.map { |launch| launch[:model][:slug] }, with_date_only.slug
  end

  test "a link that fails the allowlist is never listed, even written past validation" do
    opus.update_column(:vibe_check_url, "http://checks.every.to/vibe-checks/claude-opus-5-5")
    assert_empty launches

    opus.update_column(:vibe_check_url, "https://every.to.evil.com/x")
    assert_empty launches
  end

  test "a model that is not approved is not listed" do
    opus.update!(status: "hidden")
    assert_empty launches
  end

  test "the launch carries the model, its date and link, the newest mark and adoption" do
    launch = launches.first

    assert_equal(
      {
        model: opus.to_prop,
        released_on: opus.released_on.iso8601,
        vibe_check_url: "https://checks.every.to/vibe-checks/claude-opus-5-5",
        newest: true,
        adoption: { n: 2, of: 2 },
        mostly_in: tools(:claude).to_prop
      },
      launch
    )
    assert_equal %i[model released_on vibe_check_url newest adoption mostly_in], launch.keys
  end

  test "newest first, three at most, and only the newest is marked" do
    newer = 4.times.map { |index| add_model("Launch #{index}", released_on: (index + 1).days.ago.to_date, vibe_check_url: "https://every.to/vibe-checks/launch-#{index}") }
    list = launches

    assert_equal [ newer[0], newer[1], newer[2] ].map(&:slug), list.map { |launch| launch[:model][:slug] }
    assert_equal [ true, false, false ], list.pluck(:newest)
    assert_equal list.map { |launch| launch[:released_on] }.sort.reverse, list.pluck(:released_on)
  end

  test "adoption is N of M across all kinds, counting a person once" do
    assert_equal({ n: 2, of: 2 }, launches.first[:adoption], "ana has Opus 5.5 in two kinds")
    assert_equal({ n: 1, of: 2 }, launches(@dee, show: "others").first[:adoption], "fay only")
    assert_equal({ n: 1, of: 1 }, launches(nil).first[:adoption], "a visitor sees ana on the team")
  end

  test "AE10: a hidden person changes no adoption for colleagues but counts for themselves" do
    cy = users(:every_cy)
    add_pick(cy, :knowledge_work, 1, :claude, model: :opus_5_5)

    assert_equal({ n: 2, of: 2 }, launches.first[:adoption])
    assert_equal({ n: 3, of: 3 }, launches(cy).first[:adoption])
  end

  test "mostly in a tool only from two people, and the tool most of them use it in" do
    assert_nil launches(@dee, show: "others").first[:mostly_in], "one person"

    add_pick(add_person("gia"), :coding, 1, :claude_code, model: :opus_5_5)
    assert_equal tools(:claude_code).to_prop, launches(@dee, show: "others").first[:mostly_in], "fay and gia both on Claude Code"

    add_pick(add_person("hal"), :coding, 1, :cursor, model: :opus_5_5)
    assert_equal tools(:claude_code).to_prop, launches(@dee, show: "others").first[:mostly_in], "two on Claude Code beat one on Cursor"
  end

  test "an empty population still lists launches, with no people counted" do
    Entry.delete_all

    assert_equal({ n: 0, of: 0 }, launches(nil).first[:adoption])
    assert_nil launches(nil).first[:mostly_in]
  end

  test "the listing rule is one class method, newest first" do
    older = add_model("Older Launch", released_on: 60.days.ago.to_date, vibe_check_url: "https://every.to/vibe-checks/older")

    assert_equal [ opus, older ], ModelLaunches.models
  end

  test "launches carry no email, bio or avatar" do
    assert_no_private_fields launches
    assert_no_private_fields launches(users(:every_cy))
  end
end
