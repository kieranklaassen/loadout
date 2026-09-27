require "test_helper"

class VisibilityPeriodTest < ActiveSupport::TestCase
  test "a period is a team or link span with a start" do
    person = users(:one)

    assert VisibilityPeriod.new(user: person, level: "team", starts_at: Time.current).valid?
    assert VisibilityPeriod.new(user: person, level: "link", starts_at: Time.current).valid?
    assert_not VisibilityPeriod.new(user: person, level: "only_me", starts_at: Time.current).valid?, "only sharing is recorded"
    assert_not VisibilityPeriod.new(user: person, level: "link").valid?
    assert_not VisibilityPeriod.new(level: "link", starts_at: Time.current).valid?
  end

  test "the database allows one open period per person and only sharing levels" do
    person = users(:every_dee)
    assert_predicate person.visibility_periods.where(ends_at: nil), :one?

    assert_raises(ActiveRecord::RecordNotUnique) do
      person.visibility_periods.new(level: "link", starts_at: Time.current).save!(validate: false)
    end
    assert_raises(ActiveRecord::CheckViolation) do
      users(:one).visibility_periods.new(level: "only_me", starts_at: Time.current).save!(validate: false)
    end
  end

  test "closed periods do not count as open, so a person can share again" do
    person = users(:every_cy)

    assert_difference -> { person.visibility_periods.count } => 1 do
      person.update!(visibility: "team")
    end
    assert_equal 1, person.visibility_periods.where(ends_at: nil).count
    assert_equal 1, person.visibility_periods.where.not(ends_at: nil).count, "the past team period is kept"
  end
end
