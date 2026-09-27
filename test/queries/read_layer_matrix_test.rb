require "test_helper"
require_relative "audience_test"

# Viewer class by SHOW class, and person visibility by viewer class, against every
# surface of the read layer at once. The oracle is plain SQL over the fixture rows for the
# hand-listed people in AudienceTest::POPULATIONS, never the read layer itself.
class ReadLayerMatrixTest < ActiveSupport::TestCase
  AudienceTest::POPULATIONS.each do |viewer_name, shows|
    shows.each do |show, handles|
      test "AE1: every surface agrees on M and N for #{viewer_name.inspect} with SHOW #{show}" do
        viewer = viewer_name && users(viewer_name)
        rankings = TeamRankings.new(viewer:, show:)
        m = handles.size

        assert_equal m, rankings.people_count
        assert_equal handles, rankings.audience.people.pluck(:handle).sort

        ofs = rankings.rows.map { |row| row[:ranked][:of] } +
          rankings.overall.values.flatten.map { |entry| entry[:count][:of] } +
          ModelLaunches.new(viewer:, show:).list.map { |launch| launch[:adoption][:of] } +
          Category.all.flat_map { |category| kind_counts(rankings.kind(category)).map { |count| count[:of] } }
        assert_equal [ m ], ofs.uniq

        Category.all.each do |category|
          kind = rankings.kind(category)
          assert_equal people_with(handles, category:), kind[:ranked][:n], "K for #{category.name}"
          assert_equal kind[:ranked][:n], rankings.rows.find { |row| row[:category][:slug] == category.slug }[:ranked][:n]

          kind[:tools].each do |entry|
            tool = Tool.find_by!(slug: entry[:item][:slug])
            assert_equal people_with(handles, category:, tool:), entry[:count][:n], "#{tool.name} in #{category.name}"
            assert_equal entry[:count][:n], entry[:by_rank].values.flatten.uniq.size, "the names add up to N"
            assert_empty entry[:by_rank].values.flatten.pluck(:handle) - handles, "only people in the population are named"
          end
          kind[:models].each do |entry|
            model = AiModel.find_by!(slug: entry[:item][:slug])
            assert_equal people_with(handles, category:, model:), entry[:count][:n], "#{model.name} in #{category.name}"
            assert_equal entry[:count][:n], entry[:by_rank].values.flatten.uniq.size
          end
        end

        rankings.overall[:tools].each do |entry|
          tool = Tool.find_by!(slug: entry[:item][:slug])
          assert_equal people_with(handles, tool:), entry[:count][:n], "#{tool.name} overall"
        end
        rankings.overall[:models].each do |entry|
          model = AiModel.find_by!(slug: entry[:item][:slug])
          assert_equal people_with(handles, model:), entry[:count][:n], "#{model.name} overall"
        end
      end

      test "search and person options agree with the population for #{viewer_name.inspect} with SHOW #{show}" do
        viewer = viewer_name && users(viewer_name)
        search = Search.new(viewer:, show:)

        found = %w[ana dee cy eli fay].select { |handle| search.call(handle)[:people].any? { |person| person[:handle] == handle } }
        assert_equal handles & %w[ana dee cy eli fay], found.sort
        assert_equal handles, Audience.new(viewer:, show:).people.pluck(:handle).sort
      end
    end
  end

  # Visibility level x viewer class: does a person with picks reach each surface?

  VISIBILITY_MATRIX = {
    "only_me" => { visitor: false, other_signed_in: false, team: false, owner: true },
    "team" => { visitor: false, other_signed_in: false, team: true, owner: true },
    "link" => { visitor: true, other_signed_in: true, team: true, owner: true }
  }.freeze

  { "an Every team member" => true, "someone outside Every" => false }.each do |subject_kind, team|
    VISIBILITY_MATRIX.each do |level, reach|
      reach.each do |viewer_class, expected|
        test "#{subject_kind} sharing #{level} #{expected ? "reaches" : "does not reach"} a #{viewer_class} viewer" do
          subject = add_person("sam", visibility: level, team:)
          add_pick(subject, :video, 1, :runway, model: :opus_5_5)
          viewer = { visitor: nil, other_signed_in: users(:one), team: users(:every_dee), owner: subject }.fetch(viewer_class)
          show = team ? "team" : "others"

          audience = Audience.new(viewer:, show:)
          rankings = TeamRankings.new(viewer:, show:)
          named = rankings.kind(categories(:video))[:tools].flat_map { |entry| entry[:by_rank].values.flatten.pluck(:handle) }

          assert_equal expected, audience.people.pluck(:handle).include?("sam"), "PERSON options"
          assert_equal expected, named.include?("sam"), "named on the Kind page"
          assert_equal expected, Search.new(viewer:, show:).call("sam")[:people].any?, "search"
          already_ranking_video = team ? 0 : 1 # eli, in the other class
          assert_equal already_ranking_video + (expected ? 1 : 0), rankings.rows.find { |row| row[:category][:slug] == "video" }[:ranked][:n], "counted in the video row"
          assert_equal expected, PersonPicks.new(viewer:, show:).for(subject).present?, "person view"
          assert_equal expected, Audience.new(viewer:, show:, person: "sam").person.present?, "selectable as PERSON"
        end
      end
    end
  end

  private

  def kind_counts(kind)
    (kind[:tools] + kind[:models] + kind[:setups]).pluck(:count) + [ kind[:ranked] ]
  end

  # Distinct people among the handles with a pick matching the filters, straight from the rows.
  def people_with(handles, category: nil, tool: nil, model: nil)
    scope = Entry.joins(:user).where(users: { handle: handles })
    scope = scope.where(category:) if category
    scope = scope.where(tool:) if tool
    scope = scope.where(ai_model: model) if model
    scope.distinct.count(:user_id)
  end
end
