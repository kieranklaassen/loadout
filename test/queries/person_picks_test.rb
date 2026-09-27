require "test_helper"

# Ana (link) holds Cursor with Opus 5.5 at 1M and high effort in 1st and a plain Claude
# Code in 2nd for coding, and Claude with Opus 5.5 for knowledge work; her Runway is a
# suggestion, so video is unranked. The team viewer dee sees the team (ana and dee).
class PersonPicksTest < ActiveSupport::TestCase
  setup do
    @dee = users(:every_dee)
    @ana = users(:every_ana)
  end

  def picks(viewer = @dee, **options) = PersonPicks.new(viewer:, **options)
  def kind(result, slug) = result[:kinds].find { |kind| kind[:category][:slug] == slug }

  test "a person's picks by kind in catalog order, with the kinds they have not ranked" do
    result = picks.for(@ana)

    assert_equal %i[person ranked_count kinds new_in_loadout], result.keys
    assert_equal({ handle: "ana", name: "Ana Every", avatar_url: "https://every.to/avatars/ana.png" }, result[:person])
    assert_equal 2, result[:ranked_count]
    assert_equal %w[coding knowledge-work video], result[:kinds].map { |kind| kind[:category][:slug] }
    assert_equal categories(:coding).to_prop, kind(result, "coding")[:category]

    assert_equal(
      [
        { rank: 1, tool: tools(:cursor).to_prop, model: ai_models(:opus_5_5).to_prop, context: "1m", effort: "high" },
        { rank: 2, tool: tools(:claude_code).to_prop, model: nil, context: nil, effort: nil }
      ],
      kind(result, "coding")[:picks]
    )
    assert_equal [ 1 ], kind(result, "knowledge-work")[:picks].pluck(:rank)
    assert_empty kind(result, "video")[:picks], "a suggestion is not a pick"
  end

  test "team comparisons are left out unless asked for" do
    result = picks.for(@ana)

    assert_equal [ nil ], result[:kinds].pluck(:team_uses).uniq
    assert_empty result[:new_in_loadout]
  end

  test "team uses: only where the first pick differs from what the team uses most" do
    result = picks.for(@ana, team: true)

    assert_equal({ tool: tools(:claude_code).to_prop, model: nil }, kind(result, "coding")[:team_uses], "Cursor is ana's 1st; the team's most used tool is Claude Code, the model is the same")
    assert_nil kind(result, "knowledge-work")[:team_uses], "Claude and Opus 5.5 lead there and she has both"
    assert_nil kind(result, "video")[:team_uses]
  end

  test "team uses compares with the SHOW class the viewer is looking at" do
    eli = users(:outside_eli)
    result = picks(@dee, show: "others").for(eli, team: true)

    assert_equal({ tool: tools(:claude_code).to_prop, model: ai_models(:opus_5_5).to_prop }, kind(result, "coding")[:team_uses],
      "eli leads with Cursor and GPT-6; among eli and fay Claude Code and Opus 5.5 lead")
    assert_nil kind(result, "video")[:team_uses]
  end

  test "team uses names no model when the person picked none" do
    result = picks.for(@dee, team: true)

    assert_nil kind(result, "knowledge-work")[:team_uses], "dee's Claude has no model; the tool is the team's top"
    assert_nil kind(result, "coding")[:team_uses], "dee's first pick is the team's top tool and model"
  end

  test "AE5: new in a loadout lists the launches the person uses, in the launch shape" do
    result = picks.for(@ana, team: true)

    assert_equal 1, result[:new_in_loadout].size
    launch = result[:new_in_loadout].first
    assert_equal %i[model released_on vibe_check_url newest adoption mostly_in], launch.keys
    assert_equal ai_models(:opus_5_5).to_prop, launch[:model]
    assert_equal({ n: 2, of: 2 }, launch[:adoption])

    entries(:dee_claude_code).update!(ai_model: ai_models(:gpt_6))
    assert_empty picks.for(@dee, team: true)[:new_in_loadout], "dee's models are GPT-6, which is not a launch"
  end

  test "the person an audience selects can be passed straight in" do
    person = Audience.new(viewer: @dee, person: "ana").person

    assert_equal "ana", picks.for(person, team: true)[:person][:handle]
  end

  test "a person the viewer may not open comes back as nothing" do
    assert_nil picks.for(users(:every_cy))
    assert_nil picks(nil).for(@dee), "team-only page, visitor"
    assert_nil picks(users(:outside_eli)).for(@dee)
    assert_equal "ana", picks(nil).for(@ana)[:person][:handle]
  end

  test "the owner reads their own picks even when nobody else may" do
    result = picks(users(:every_cy)).for(users(:every_cy))

    assert_equal 1, result[:ranked_count]
    assert_equal ai_models(:opus_5).slug, kind(result, "coding")[:picks].first[:model][:slug]
  end

  test "someone who shares but has no picks gets an empty loadout, not nothing" do
    add_person("quinn", visibility: "team", team: true)
    result = picks.for(User.find_by!(handle: "quinn"), team: true)

    assert_equal 0, result[:ranked_count]
    assert_equal [ [], [], [] ], result[:kinds].pluck(:picks)
    assert_empty result[:new_in_loadout]
  end

  test "pending items show only to their owner, who sees them marked" do
    zed = add_tool("Zed", status: "pending", created_by: @ana)
    beta = add_model("Beta", status: "pending", created_by: @ana)
    add_pick(@ana, :coding, 3, zed)
    entries(:ana_claude_code).update!(ai_model: beta)

    others = kind(picks.for(@ana), "coding")[:picks]
    assert_equal [ 1, 2 ], others.pluck(:rank)
    assert_nil others.last[:model], "a pending model is hidden from colleagues"

    own = kind(picks(@ana).for(@ana), "coding")[:picks]
    assert_equal [ 1, 2, 3 ], own.pluck(:rank)
    assert_equal [ true, true ], [ own.last[:tool][:pending], own.second[:model][:pending] ]

    zed.update!(status: "approved")
    beta.update!(status: "approved")
    colleague = kind(picks.for(@ana), "coding")[:picks]
    assert_equal [ 1, 2, 3 ], colleague.pluck(:rank)
    assert_equal beta.slug, colleague.second[:model][:slug]
  end

  test "someone whose only pick is pending has no ranked kinds for colleagues" do
    ren = add_person("ren", team: true)
    add_pick(ren, :coding, 1, add_tool("Zed", status: "pending", created_by: ren))

    assert_equal 0, picks.for(ren)[:ranked_count]
    assert_equal 1, picks(ren).for(ren)[:ranked_count]
  end

  test "only the person entry carries an avatar; no email or bio anywhere" do
    result = picks.for(@ana, team: true)

    assert_equal %i[handle name avatar_url], result[:person].keys
    assert_equal %i[category picks team_uses], result[:kinds].first.keys
    assert_equal %i[rank tool model context effort], kind(result, "coding")[:picks].first.keys
    assert_no_private_fields result
    assert_empty all_keys(result[:kinds]) & %i[avatar_url]
  end
end
