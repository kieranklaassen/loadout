require "test_helper"

# Hand-derived from test/fixtures for the Every team seen by a team viewer (dee): the
# population is ana and dee (M = 2; cy is only me). Coding: both rank Claude Code and
# Cursor (2 of 2 each, one 1st pick each, so name breaks the tie), Opus 5.5 is on both
# (2 of 2, two 1st picks), GPT-6 only on dee's Cursor. Knowledge work: both use Claude,
# only ana names a model. Video: nobody in the team ranks it (ana's is a suggestion).
# The rest (eli, fay) are M = 2 too; the two classes together are the 4 people and the
# counts (Cursor 3, Claude Code 4, Opus 5.5 3, GPT-6 2) the fixture notes give.
class TeamRankingsTest < ActiveSupport::TestCase
  setup do
    @dee = users(:every_dee)
    @team = TeamRankings.new(viewer: @dee)
    @others = TeamRankings.new(viewer: @dee, show: "others")
  end

  def row(rankings, slug) = rankings.rows.find { |row| row[:category][:slug] == slug }
  def slugs(items) = items.map { |entry| entry[:item][:slug] }
  def item(record) = record.to_prop
  def count(n, of) = { n:, of: }
  def iso(fixture) = entry_changes(fixture).created_at.iso8601

  # AE1 (the counting rule) and the Home rows contract

  test "rows: one per kind in catalog order with the top tool, top model and one runner-up each" do
    assert_equal %w[coding knowledge-work video], @team.rows.map { |row| row[:category][:slug] }

    assert_equal(
      {
        category: categories(:coding).to_prop,
        top_tool: { item: item(tools(:claude_code)), count: count(2, 2), runner_up: { item: item(tools(:cursor)), count: count(2, 2) } },
        top_model: { item: item(ai_models(:opus_5_5)), count: count(2, 2), runner_up: { item: item(ai_models(:gpt_6)), count: count(1, 2) } },
        ranked: count(2, 2),
        last_update_at: iso(:ana_4),
        stale: false
      },
      row(@team, "coding")
    )
  end

  test "rows: a kind with tools but one model, and a kind nobody ranked, keep their place" do
    assert_equal(
      {
        category: categories(:knowledge_work).to_prop,
        top_tool: { item: item(tools(:claude)), count: count(2, 2), runner_up: nil },
        top_model: { item: item(ai_models(:opus_5_5)), count: count(1, 2), runner_up: nil },
        ranked: count(2, 2),
        last_update_at: iso(:ana_5),
        stale: false
      },
      row(@team, "knowledge-work")
    )

    assert_equal(
      { category: categories(:video).to_prop, top_tool: nil, top_model: nil, ranked: count(0, 2), last_update_at: nil, stale: false },
      row(@team, "video")
    )
  end

  test "rows: the other SHOW class counts its own people" do
    coding = row(@others, "coding")

    assert_equal [ tools(:claude_code).slug, count(2, 2), tools(:cursor).slug, count(1, 2) ],
      [ coding[:top_tool][:item][:slug], coding[:top_tool][:count], coding[:top_tool][:runner_up][:item][:slug], coding[:top_tool][:runner_up][:count] ]
    assert_equal count(2, 2), coding[:ranked]
    assert_equal iso(:fay_1), coding[:last_update_at]

    video = row(@others, "video")
    assert_equal [ tools(:runway).slug, count(1, 2), nil, nil ], [ video[:top_tool][:item][:slug], video[:top_tool][:count], video[:top_tool][:runner_up], video[:top_model] ]
    assert_equal count(0, 2), row(@others, "knowledge-work")[:ranked]
  end

  test "the two SHOW classes add up to the people and counts the fixtures were derived for" do
    coding = categories(:coding)
    combined = ->(kind, record) { [ @team, @others ].sum { |rankings| rankings.item_counts(category: coding)[kind].fetch(record.id, count(0, 0))[:n] } }

    assert_equal 3, combined.call(:tools, tools(:cursor))
    assert_equal 4, combined.call(:tools, tools(:claude_code))
    assert_equal 3, combined.call(:models, ai_models(:opus_5_5))
    assert_equal 2, combined.call(:models, ai_models(:gpt_6))
    assert_equal 0, combined.call(:models, ai_models(:opus_5)), "Opus 5 is only on hidden cy"
    assert_equal 4, @team.people_count + @others.people_count
  end

  test "M is the same in every count of one audience" do
    coding = categories(:coding)
    [ @team, @others ].each do |rankings|
      m = rankings.people_count
      ofs = rankings.rows.map { |row| row[:ranked][:of] } +
        rankings.overall.values.flatten.map { |entry| entry[:count][:of] } +
        rankings.kind(coding).values_at(:tools, :models).flatten.map { |entry| entry[:count][:of] } +
        [ rankings.kind(coding)[:ranked][:of] ] +
        rankings.item_counts.values.flat_map(&:values).map { |c| c[:of] }

      assert_equal [ m ], ofs.uniq
    end
  end

  # Overall

  test "overall: distinct people across kinds, ranked by people, then 1st picks, then name" do
    overall = @team.overall

    assert_equal %w[claude claude-code cursor], slugs(overall[:tools])
    assert_equal [ count(2, 2) ] * 3, overall[:tools].pluck(:count)
    assert_equal %w[claude-opus-5-5 gpt-6-astra], slugs(overall[:models])
    assert_equal [ count(2, 2), count(1, 2) ], overall[:models].pluck(:count)
  end

  test "overall: a person with a model in two kinds is counted once" do
    assert_equal count(2, 2), @team.item_counts[:models].fetch(ai_models(:opus_5_5).id), "ana has Opus 5.5 in coding and knowledge work"
  end

  test "overall lists at most ten tools and ten models" do
    newcomer = add_person("newcomer")
    4.times do |index|
      kind = Category.create!(slug: "extra-#{index}", name: "Extra #{index}", position: 10 + index)
      3.times { |rank| add_pick(newcomer, kind, rank + 1, add_tool("Tool #{index}-#{rank}"), model: add_model("Model #{index}-#{rank}")) }
    end

    overall = TeamRankings.new(viewer: nil, show: "others").overall

    assert_equal 10, overall[:tools].size
    assert_equal 10, overall[:models].size
  end

  # Ties

  test "equal people and 1st picks break by name; equal people break by 1st picks before name" do
    assert_equal %w[claude-code cursor], slugs(@team.kind(categories(:coding))[:tools]), "2 of 2 and one 1st pick each: Claude Code before Cursor by name"

    gia = add_person("gia")
    add_pick(gia, :coding, 1, :cursor)
    coding = TeamRankings.new(viewer: nil, show: "others").kind(categories(:coding))

    assert_equal %w[cursor claude-code], slugs(coding[:tools]), "2 of 3 each, but Cursor has two 1st picks against one"
    assert_equal [ count(2, 3), count(2, 3) ], coding[:tools].pluck(:count)
  end

  # Kind detail

  test "kind: K of M ranked it, tools and models with who ranked them 1st, 2nd and 3rd" do
    coding = @team.kind(categories(:coding))
    ana = { handle: "ana", name: "Ana Every" }
    dee = { handle: "dee", name: "Dee Every" }

    assert_equal count(2, 2), coding[:ranked]
    assert_equal categories(:coding).to_prop, coding[:category]
    assert_equal [ item(tools(:claude_code)), item(tools(:cursor)) ], coding[:tools].pluck(:item)
    assert_equal [ { 1 => [ dee ], 2 => [ ana ], 3 => [] }, { 1 => [ ana ], 2 => [ dee ], 3 => [] } ], coding[:tools].pluck(:by_rank)
    assert_equal [ item(ai_models(:opus_5_5)), item(ai_models(:gpt_6)) ], coding[:models].pluck(:item)
    assert_equal [ count(2, 2), count(1, 2) ], coding[:models].pluck(:count)
    assert_equal [ { 1 => [ ana, dee ], 2 => [], 3 => [] }, { 1 => [], 2 => [ dee ], 3 => [] } ], coding[:models].pluck(:by_rank)
    assert_equal iso(:ana_4), coding[:last_update_at]
  end

  test "kind: the names for an item add up to its count, for every kind and audience" do
    [ @team, @others, TeamRankings.new(viewer: users(:every_cy)), TeamRankings.new(viewer: nil) ].each do |rankings|
      Category.all.each do |category|
        kind = rankings.kind(category)
        (kind[:tools] + kind[:models]).each do |entry|
          named = entry[:by_rank].values.flatten.uniq
          assert_equal entry[:count][:n], named.size, "#{entry[:item][:name]} in #{category.name}"
        end
      end
    end
  end

  test "kind: K counts the people with any pick in the kind, and an unranked kind is 0 of M" do
    assert_equal count(2, 2), @team.kind(categories(:knowledge_work))[:ranked]

    video = @team.kind(categories(:video))
    assert_equal({ ranked: count(0, 2), tools: [], models: [], setups: [], takes: [], last_update_at: nil }, video.slice(:ranked, :tools, :models, :setups, :takes, :last_update_at))
  end

  test "a pick without a model counts for its tool and for no model" do
    knowledge = @team.kind(categories(:knowledge_work))

    assert_equal [ count(2, 2) ], knowledge[:tools].pluck(:count)
    assert_equal [ item(ai_models(:opus_5_5)) ], knowledge[:models].pluck(:item)
    assert_equal [ count(1, 2) ], knowledge[:models].pluck(:count), "dee's Claude pick names no model"
  end

  test "setups group by tool, model, context and effort and count people" do
    setups = @team.kind(categories(:coding))[:setups]

    assert_equal(
      [
        { tool: item(tools(:claude_code)), model: item(ai_models(:opus_5_5)), context: nil, effort: "medium", count: count(1, 2) },
        { tool: item(tools(:cursor)), model: item(ai_models(:opus_5_5)), context: "1m", effort: "high", count: count(1, 2) },
        { tool: item(tools(:cursor)), model: item(ai_models(:gpt_6)), context: nil, effort: nil, count: count(1, 2) }
      ],
      setups
    )
  end

  test "setups: a person may appear in two, null context and effort are their own group, and a setup never beats its tool or model" do
    # dee also runs Cursor with Opus 5.5 at 1M and high, like ana does; ana's plain Claude Code gains a model.
    add_pick(users(:every_dee), :coding, 3, :runway, model: :opus_5_5, context: "1m", effort: "high")
    entries(:ana_claude_code).update!(ai_model: ai_models(:gpt_6))
    coding = TeamRankings.new(viewer: @dee).kind(categories(:coding))

    opus_1m = coding[:setups].find { |setup| setup[:model][:slug] == "claude-opus-5-5" && setup[:context] == "1m" }
    assert_equal count(1, 2), opus_1m[:count], "one person per tool here"
    gpt = coding[:setups].select { |setup| setup[:model][:slug] == "gpt-6-astra" }
    assert_equal 2, gpt.size, "ana on Claude Code, dee on Cursor: separate groups"
    assert_includes gpt.pluck(:context), nil

    bound = ->(setup) do
      tool = coding[:tools].find { |entry| entry[:item][:slug] == setup[:tool][:slug] }[:count][:n]
      model = coding[:models].find { |entry| entry[:item][:slug] == setup[:model][:slug] }[:count][:n]
      [ tool, model ].min
    end
    coding[:setups].each { |setup| assert_operator setup[:count][:n], :<=, bound.call(setup) }
    assert_operator coding[:setups].sum { |setup| setup[:count][:n] }, :>, 2, "two people, more setups: people appear in several"
  end

  test "takes: the Vibe Check links of launched models people ranked in the kind" do
    expected = [ { model: item(ai_models(:opus_5_5)), url: ai_models(:opus_5_5).vibe_check_url } ]

    assert_equal expected, @team.kind(categories(:coding))[:takes]
    assert_equal expected, @team.kind(categories(:knowledge_work))[:takes]
    assert_empty @team.kind(categories(:video))[:takes]

    entries(:ana_claude).update!(ai_model: nil)
    assert_empty TeamRankings.new(viewer: @dee).kind(categories(:knowledge_work))[:takes], "nobody ranks a launched model there any more"
  end

  test "takes: only a launched model, never one without a date or with a link that fails the allowlist" do
    ai_models(:gpt_6).update!(vibe_check_url: "https://checks.every.to/vibe-checks/gpt-6")
    assert_equal %w[claude-opus-5-5], @team.kind(categories(:coding))[:takes].map { |take| take[:model][:slug] }, "a link without a date is not a launch"

    ai_models(:opus_5_5).update_column(:vibe_check_url, "http://evil.example/steal")
    assert_empty TeamRankings.new(viewer: @dee).kind(categories(:coding))[:takes], "a raw value past validation never becomes a link"
  end

  # Hidden people, the owner, pending items

  test "AE2: a hidden person is in no count or name for colleagues, and counted for themselves" do
    coding = @team.kind(categories(:coding))
    assert_equal count(2, 2), coding[:tools].find { |entry| entry[:item][:slug] == "cursor" }[:count]
    assert_not_includes slugs(coding[:models]), "claude-opus-5"
    assert_not_includes coding[:tools].flat_map { |entry| entry[:by_rank].values.flatten.pluck(:handle) }, "cy"

    own = TeamRankings.new(viewer: users(:every_cy))
    assert_equal count(3, 3), own.kind(categories(:coding))[:tools].find { |entry| entry[:item][:slug] == "cursor" }[:count]
    assert_equal %w[claude-opus-5-5 claude-opus-5 gpt-6-astra], slugs(own.kind(categories(:coding))[:models]), "Opus 5 has one 1st pick, GPT-6 none"
    assert_equal count(3, 3), row(own, "coding")[:ranked]
  end

  test "AE10: nothing a hidden person does changes what a colleague gets" do
    read = ->(viewer) do
      rankings = TeamRankings.new(viewer:)
      [ rankings.rows, rankings.hero, rankings.overall, rankings.team_top, Category.all.map { |category| rankings.kind(category) }, rankings.item_counts ].to_json
    end
    before = [ @dee, users(:outside_eli), nil ].map { |viewer| read.call(viewer) }

    cy = users(:every_cy)
    add_pick(cy, :video, 1, :runway)
    add_pick(cy, :knowledge_work, 1, :claude, model: :opus_5_5)
    cy.update!(visibility: "team")
    cy.update!(visibility: "only_me")
    cy.update!(handle: "cy-renamed")
    add_tool("Cy Only", status: "pending", created_by: cy)

    assert_equal before, [ @dee, users(:outside_eli), nil ].map { |viewer| read.call(viewer) }
  end

  test "a pending tool or model is counted for no one until it is approved, then retroactively" do
    ana = users(:every_ana)
    zed = add_tool("Zed", status: "pending", created_by: ana)
    beta = add_model("Beta Model", status: "pending", created_by: ana)
    add_pick(ana, :coding, 3, zed)
    entries(:ana_claude_code).update!(ai_model: beta)

    [ @dee, ana, nil ].each do |viewer|
      coding = TeamRankings.new(viewer:).kind(categories(:coding))
      assert_not_includes slugs(coding[:tools]), "zed"
      assert_not_includes slugs(coding[:models]), "beta-model"
      assert_equal 2, coding[:tools].size
    end
    assert_equal count(2, 2), row(TeamRankings.new(viewer: @dee), "coding")[:ranked]

    zed.update!(status: "approved")
    beta.update!(status: "approved")
    coding = TeamRankings.new(viewer: @dee).kind(categories(:coding))
    assert_equal count(1, 2), coding[:tools].find { |entry| entry[:item][:slug] == "zed" }[:count]
    assert_equal count(1, 2), coding[:models].find { |entry| entry[:item][:slug] == "beta-model" }[:count]
  end

  test "a hidden catalog item is not counted either" do
    tools(:cursor).update!(status: "hidden")

    assert_not_includes slugs(TeamRankings.new(viewer: @dee).kind(categories(:coding))[:tools]), "cursor"
  end

  test "suggestions count nowhere" do
    assert PickSuggestion.open.exists?(user: users(:every_ana), category: categories(:video)), "ana has an open Runway suggestion"
    assert_equal count(0, 2), row(@team, "video")[:ranked]
    assert_empty @team.kind(categories(:video))[:tools]
  end

  # Last update and staleness

  test "last update reads confirmed changes of the people counted, not suggestions" do
    assert_nil row(@team, "video")[:last_update_at], "ana's suggested row in video is not an update"
    assert_equal iso(:ana_5), row(@team, "knowledge-work")[:last_update_at], "the newer of ana's 20 days and dee's 35"
    assert_equal iso(:eli_3), row(@others, "video")[:last_update_at]
  end

  test "stale from 6 weeks, by UTC date" do
    change = entry_changes(:eli_3)

    change.update_columns(created_at: 41.days.ago)
    assert_equal false, row(TeamRankings.new(viewer: @dee, show: "others"), "video")[:stale]

    change.update_columns(created_at: 42.days.ago)
    video = row(TeamRankings.new(viewer: @dee, show: "others"), "video")
    assert_equal true, video[:stale]
    assert_equal change.reload.created_at.iso8601, video[:last_update_at]
  end

  test "a removal and a move are updates too" do
    EntryChange.create!(user: users(:every_dee), category: categories(:knowledge_work), tool: tools(:claude), action: "removed", source: "web", rank: 2, created_at: 1.hour.ago)

    assert_operator Time.iso8601(row(TeamRankings.new(viewer: @dee), "knowledge-work")[:last_update_at]), :>, 2.hours.ago
  end

  # Hero

  test "hero: the busiest kinds with the team's top three tools and their usual models, plus totals" do
    hero = @team.hero

    assert_equal %i[boards people picks last_update_at], hero.keys
    assert_equal 2, hero[:people]
    assert_equal 6, hero[:picks]
    assert_equal iso(:ana_5), hero[:last_update_at]
    assert_equal(
      [
        {
          category: categories(:coding).to_prop,
          picks: [
            { rank: 1, tool: item(tools(:claude_code)), model: item(ai_models(:opus_5_5)) },
            { rank: 2, tool: item(tools(:cursor)), model: item(ai_models(:opus_5_5)) }
          ]
        },
        { category: categories(:knowledge_work).to_prop, picks: [ { rank: 1, tool: item(tools(:claude)), model: item(ai_models(:opus_5_5)) } ] }
      ],
      hero[:boards]
    )
  end

  test "hero: the kind with the most people comes first, whatever its place in the catalog" do
    2.times { |index| add_pick(add_person("viewer#{index}"), :video, 1, :runway) }
    boards = TeamRankings.new(viewer: nil, show: "others").hero[:boards]

    assert_equal %w[video coding], boards.map { |board| board[:category][:slug] }, "video has eli and two more, coding eli and fay"
  end

  test "hero: a tool nobody pairs with a model has none, and at most three boards of three picks" do
    others = TeamRankings.new(viewer: nil, show: "others").hero
    assert_nil others[:boards].find { |board| board[:category][:slug] == "video" }[:picks].first[:model]

    newcomer = add_person("busy")
    [ :coding, :knowledge_work, :video ].each { |kind| add_pick(newcomer, kind, 1, :runway) }
    Category.create!(slug: "fourth", name: "Fourth", position: 9).then { |kind| add_pick(newcomer, kind, 1, :claude) }
    add_pick(newcomer, :coding, 2, :cursor)
    add_pick(newcomer, :coding, 3, :claude)
    boards = TeamRankings.new(viewer: nil, show: "others").hero[:boards]

    assert_equal 3, boards.size
    assert_equal "coding", boards.first[:category][:slug], "coding has the most people"
    assert_equal [ 1, 2, 3 ], boards.first[:picks].pluck(:rank), "four tools, three shown"
  end

  # Empty population

  test "an empty population gives no rows, no hero and a reason, never 0 of 0 rows" do
    assert_nil @team.empty_reason

    Entry.delete_all
    rankings = TeamRankings.new(viewer: nil)

    assert_equal 0, rankings.people_count
    assert_equal "nobody_shared", rankings.empty_reason
    assert_empty rankings.rows
    assert_nil rankings.hero
    assert_equal({ tools: [], models: [] }, rankings.overall)
    assert_equal({ tools: {}, models: {} }, rankings.item_counts)
    assert_equal({ n: 0, of: 0 }, rankings.kind(categories(:coding))[:ranked])
  end

  test "SHOW subscribers gives the team's numbers and the notice" do
    rankings = TeamRankings.new(viewer: @dee, show: "subscribers")

    assert_equal @team.rows, rankings.rows
    assert_match(/subscribers/i, rankings.audience.notice)
  end

  # item_counts is the one place N of M is computed

  test "item_counts: Count per item, in ranking order, for one kind or across kinds" do
    coding = @team.item_counts(category: categories(:coding))

    assert_equal [ tools(:claude_code).id, tools(:cursor).id ], coding[:tools].keys
    assert_equal count(2, 2), coding[:tools][tools(:cursor).id]
    assert_equal [ ai_models(:opus_5_5).id, ai_models(:gpt_6).id ], coding[:models].keys
    assert_equal count(1, 2), coding[:models][ai_models(:gpt_6).id]

    assert_equal count(1, 2), @team.item_counts(category: categories(:knowledge_work))[:models][ai_models(:opus_5_5).id]
    assert_equal count(2, 2), @team.item_counts[:models][ai_models(:opus_5_5).id]
  end

  test "count_of: zero for an item nobody ranked, with the same M" do
    assert_equal count(0, 2), @team.count_of(:model, ai_models(:opus_5).id)
    assert_equal count(2, 2), @team.count_of(:tool, tools(:cursor).id, category: categories(:coding))
    assert_equal count(0, 2), @team.count_of(:tool, tools(:runway).id)
  end

  test "mostly_in: the tool most people use a model in, only from two people" do
    opus = ai_models(:opus_5_5)
    others = TeamRankings.new(viewer: @dee, show: "others")
    assert_nil others.mostly_in(opus), "only fay uses Opus 5.5 there"

    add_pick(add_person("gia"), :coding, 1, :claude_code, model: :opus_5_5)
    assert_equal item(tools(:claude_code)), TeamRankings.new(viewer: @dee, show: "others").mostly_in(opus)
  end

  # Editor

  test "team_top: per kind the top tools and models with your rank and which models are launches" do
    top = @team.team_top

    assert_equal %w[coding knowledge-work video], top.keys
    assert_equal(
      {
        tools: [ { item: item(tools(:claude_code)), count: count(2, 2), yours_rank: 1 }, { item: item(tools(:cursor)), count: count(2, 2), yours_rank: 2 } ],
        models: [
          { item: item(ai_models(:opus_5_5)), count: count(2, 2), yours_rank: 1, launched: true },
          { item: item(ai_models(:gpt_6)), count: count(1, 2), yours_rank: 2, launched: false }
        ]
      },
      top["coding"]
    )
    assert_equal({ tools: [ { item: item(tools(:claude)), count: count(2, 2), yours_rank: 1 } ], models: [ { item: item(ai_models(:opus_5_5)), count: count(1, 2), yours_rank: nil, launched: true } ] }, top["knowledge-work"])
    assert_equal({ tools: [], models: [] }, top["video"])
  end

  test "team_top: a model in two of your slots reports the better rank; a visitor has no ranks" do
    add_pick(@dee, :knowledge_work, 2, :cursor, model: :opus_5_5)
    add_pick(@dee, :knowledge_work, 3, :runway, model: :opus_5_5)
    model = TeamRankings.new(viewer: @dee).team_top["knowledge-work"][:models].first
    assert_equal [ "claude-opus-5-5", 2 ], [ model[:item][:slug], model[:yours_rank] ]

    visitor = TeamRankings.new(viewer: nil).team_top
    assert_equal [ nil ], visitor.values.flat_map { |kind| kind.values.flatten.map { |entry| entry[:yours_rank] } }.uniq
  end

  test "team_top lists at most five of each" do
    newcomer = add_person("many")
    seven = Array.new(7) { |index| add_tool("Many Tool #{index}") }
    kind = Category.create!(slug: "many", name: "Many", position: 20)
    seven.first(3).each_with_index { |tool, index| add_pick(newcomer, kind, index + 1, tool) }
    seven.drop(3).each_slice(3).with_index do |tools, offset|
      other = add_person("many-#{offset}")
      tools.each_with_index { |tool, index| add_pick(other, kind, index + 1, tool) }
    end

    assert_equal 5, TeamRankings.new(viewer: nil, show: "others").team_top["many"][:tools].size
  end

  # Contracts

  test "the outputs have exactly their contract keys and no email, bio or avatar" do
    coding = categories(:coding)
    rows = @team.rows.first

    assert_equal %i[category top_tool top_model ranked last_update_at stale], rows.keys
    assert_equal %i[item count runner_up], rows[:top_tool].keys
    assert_equal %i[item count], rows[:top_tool][:runner_up].keys
    assert_equal %i[boards people picks last_update_at], @team.hero.keys
    assert_equal %i[category picks], @team.hero[:boards].first.keys
    assert_equal %i[rank tool model], @team.hero[:boards].first[:picks].first.keys
    assert_equal %i[tools models], @team.overall.keys
    assert_equal %i[item count], @team.overall[:tools].first.keys
    kind = @team.kind(coding)
    assert_equal %i[category ranked tools models setups takes last_update_at], kind.keys
    assert_equal %i[item count by_rank], kind[:tools].first.keys
    assert_equal [ 1, 2, 3 ], kind[:tools].first[:by_rank].keys
    assert_equal %i[handle name], kind[:tools].first[:by_rank][1].first.keys
    assert_equal %i[tool model context effort count], kind[:setups].first.keys
    assert_equal %i[model url], kind[:takes].first.keys
    assert_equal %i[tools models], @team.team_top["coding"].keys
    assert_equal %i[item count yours_rank], @team.team_top["coding"][:tools].first.keys
    assert_equal %i[item count yours_rank launched], @team.team_top["coding"][:models].first.keys

    [ @team, @others, TeamRankings.new(viewer: users(:every_cy)), TeamRankings.new(viewer: nil) ].each do |rankings|
      assert_no_private_fields [ rankings.rows, rankings.hero, rankings.overall, rankings.team_top, Category.all.map { |c| rankings.kind(c) } ]
      assert_empty all_keys([ rankings.rows, rankings.hero, rankings.overall, rankings.team_top, Category.all.map { |c| rankings.kind(c) } ]) & %i[avatar_url]
    end
  end
end
