require "test_helper"
require_relative "audience_test"

# Viewer class by SHOW class, and person visibility by viewer class, against every
# surface of the read layer at once. The oracle is plain SQL over the fixture rows for the
# hand-listed people in AudienceTest::POPULATIONS, never the read layer itself: every count
# is over the counted people (on the team, every onboarded member whatever their
# visibility), and only the named people (those the viewer may open) are ever named.
class ReadLayerMatrixTest < ActiveSupport::TestCase
  AudienceTest::POPULATIONS.each do |viewer_name, shows|
    shows.each do |show, (named, counted)|
      test "AE1: every surface agrees on M and N for #{viewer_name.inspect} with SHOW #{show}" do
        viewer = viewer_name && users(viewer_name)
        rankings = TeamRankings.new(viewer:, show:)
        m = counted.size

        assert_equal m, rankings.people_count
        assert_equal named, rankings.audience.people.pluck(:handle).sort

        ofs = rankings.rows.map { |row| row[:ranked][:of] } +
          rankings.overall.values.flatten.map { |entry| entry[:count][:of] } +
          ModelLaunches.new(viewer:, show:).list.map { |launch| launch[:adoption][:of] } +
          Category.all.flat_map { |category| kind_counts(rankings.kind(category)).map { |count| count[:of] } }
        assert_equal [ m ], ofs.uniq

        Category.all.each do |category|
          kind = rankings.kind(category)
          assert_equal people_with(counted, category:), kind[:ranked][:n], "K for #{category.name}"
          assert_equal kind[:ranked][:n], rankings.rows.find { |row| row[:category][:slug] == category.slug }[:ranked][:n]

          kind[:tools].each do |entry|
            tool = Tool.find_by!(slug: entry[:item][:slug])
            assert_equal people_with(counted, category:, tool:), entry[:count][:n], "#{tool.name} in #{category.name}"
            assert_names_add_up entry, named, category:, tool:
          end
          kind[:models].each do |entry|
            model = AiModel.find_by!(slug: entry[:item][:slug])
            assert_equal people_with(counted, category:, model:), entry[:count][:n], "#{model.name} in #{category.name}"
            assert_names_add_up entry, named, category:, model:
          end
        end

        rankings.overall[:tools].each do |entry|
          tool = Tool.find_by!(slug: entry[:item][:slug])
          assert_equal people_with(counted, tool:), entry[:count][:n], "#{tool.name} overall"
        end
        rankings.overall[:models].each do |entry|
          model = AiModel.find_by!(slug: entry[:item][:slug])
          assert_equal people_with(counted, model:), entry[:count][:n], "#{model.name} overall"
        end
      end

      test "search and person options offer only the named people for #{viewer_name.inspect} with SHOW #{show}" do
        viewer = viewer_name && users(viewer_name)
        search = Search.new(viewer:, show:)

        found = %w[ana dee cy eli fay].select { |handle| search.call(handle)[:people].any? { |person| person[:handle] == handle } }
        assert_equal named & %w[ana dee cy eli fay], found.sort
        assert_equal named, Audience.new(viewer:, show:).people.pluck(:handle).sort
        (counted - named).each do |handle|
          assert_nil Audience.new(viewer:, show:, person: handle).person, "#{handle} is counted but not selectable"
        end
      end
    end
  end

  # Visibility level x viewer class: is a person with picks named on each surface, and counted?
  # On the team a member is counted for every viewer whatever they share; outside it, only
  # where they are named.

  VISIBILITY_MATRIX = {
    "only_me" => { visitor: false, other_signed_in: false, team: false, owner: true },
    "team" => { visitor: false, other_signed_in: false, team: true, owner: true },
    "link" => { visitor: true, other_signed_in: true, team: true, owner: true }
  }.freeze

  { "an Every team member" => true, "someone outside Every" => false }.each do |subject_kind, team|
    VISIBILITY_MATRIX.each do |level, reach|
      reach.each do |viewer_class, expected|
        test "#{subject_kind} sharing #{level} #{expected ? "is named for" : "is not named for"} a #{viewer_class} viewer" do
          subject = add_person("sam", visibility: level, team:)
          add_pick(subject, :video, 1, :runway, model: :opus_5_5)
          viewer = { visitor: nil, other_signed_in: users(:one), team: users(:every_dee), owner: subject }.fetch(viewer_class)
          show = team ? "team" : "others"
          counted = team || expected

          audience = Audience.new(viewer:, show:)
          rankings = TeamRankings.new(viewer:, show:)
          runway = rankings.kind(categories(:video))[:tools].find { |entry| entry[:item][:slug] == "runway" }
          named = runway ? runway[:by_rank].values.flatten.pluck(:handle) : []

          assert_equal expected, audience.people.pluck(:handle).include?("sam"), "PERSON options"
          assert_equal expected, named.include?("sam"), "named on the Kind page"
          assert_equal expected, Search.new(viewer:, show:).call("sam")[:people].any?, "search"
          already_ranking_video = team ? 0 : 1 # eli, in the other class
          assert_equal already_ranking_video + (counted ? 1 : 0), rankings.rows.find { |row| row[:category][:slug] == "video" }[:ranked][:n], "counted in the video row"
          assert_equal (counted && !expected ? 1 : 0), runway ? runway[:unnamed] : 0, "counted but unnamed on the Kind page"
          assert_equal expected, PersonPicks.new(viewer:, show:).for(subject).present?, "person view"
          assert_equal expected, Audience.new(viewer:, show:, person: "sam").person.present?, "selectable as PERSON"
          assert_not_includes rankings.kind(categories(:video)).to_json, "Sam" unless expected
        end
      end
    end
  end

  private

  def kind_counts(kind)
    (kind[:tools] + kind[:models] + kind[:setups]).pluck(:count) + [ kind[:ranked] ]
  end

  # The named holders are exactly the named people with the item, and with the unnamed ones they make N.
  def assert_names_add_up(entry, named, **filters)
    names = entry[:by_rank].values.flatten.pluck(:handle)
    assert_equal names.uniq.sort, names.sort, "nobody is named twice"
    assert_equal handles_with(named, **filters), names.sort, "#{entry[:item][:name]}: only the named people who have it"
    assert_equal entry[:count][:n], names.size + entry[:unnamed], "#{entry[:item][:name]}: the names and the unnamed add up to N"
  end

  # Distinct people among the handles with a pick matching the filters, straight from the rows.
  def people_with(handles, **filters)
    handles_with(handles, **filters).size
  end

  def handles_with(handles, category: nil, tool: nil, model: nil)
    scope = Entry.joins(:user).where(users: { handle: handles })
    scope = scope.where(category:) if category
    scope = scope.where(tool:) if tool
    scope = scope.where(ai_model: model) if model
    scope.distinct.pluck("users.handle").sort
  end
end
