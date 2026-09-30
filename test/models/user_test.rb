require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "handles are normalized, validated, unique, and not reserved" do
    user = users(:one)
    user.handle = " @Kieran "
    assert_equal "kieran", user.handle
    assert user.valid?

    user.handle = "map"
    assert_not user.valid?
    assert_includes user.errors[:handle], "is reserved"

    user.handle = "kinds"
    assert_not user.valid?, "the kinds route is reserved"

    user.handle = "no_underscores"
    assert_not user.valid?

    user.handle = "x"
    assert_not user.valid?

    user.handle = users(:every_ana).handle
    assert_not user.valid?
  end

  test "suggest_handle derives a free handle from a name" do
    assert_equal "kieran-klaassen", User.suggest_handle(from: "Kieran Klaassen")
    assert_equal "ana-2", User.suggest_handle(from: "Ana")
    assert_equal "member", User.suggest_handle(from: "?")
  end

  test "onboarded? needs a handle and a finished onboarding" do
    assert users(:every_ana).onboarded?
    assert_not users(:one).onboarded?
  end

  # Every team (AE11)

  ADDRESSES = {
    "zed@every.to" => true,
    "Zoe@Every.To" => true,
    "zia@every.to.evil.com" => false,
    "zak@evil-every.to" => false,
    "a@b@every.to" => false,
    "x@sub.every.to" => false,
    "zip@EVERY.TO.evil.com" => false,
    "@every.to" => false,
    "zen@gmail.com" => false
  }.freeze

  test "the Every team is a verified @every.to address, exactly, in Ruby and in SQL" do
    ADDRESSES.each do |address, expected|
      user = User.create!(email_address: address, email_verified: true)

      assert_equal expected, user.every_member?, "every_member? for #{address}"
      assert_equal expected, User.every_members.exists?(id: user.id), "User.every_members for #{address}"
    end
  end

  test "an @every.to address the provider did not verify is not on the team" do
    user = User.create!(email_address: "ana2@every.to", email_verified: false)

    assert_not user.every_member?
    assert_not User.every_members.exists?(id: user.id)
    assert_includes User.every_members, users(:every_ana)
    assert_not_includes User.every_members, users(:every_fay)
  end

  test "admin? is true for the admin column, or an ADMIN_EMAILS address the provider verified" do
    ana = users(:every_ana)
    assert_not ana.admin?
    assert User.new(email_address: "boss@example.com", admin: true).admin?

    ENV["ADMIN_EMAILS"] = "someone@else.com, ANA@every.to"
    assert ana.admin?

    ana.email_verified = false
    assert_not ana.admin?, "an unverified address does not grant admin"
  ensure
    ENV.delete("ADMIN_EMAILS")
  end

  # Visibility (R12, R13, KTD5)

  test "a member starts public once they claim a handle; before that a page cannot be shared" do
    assert_equal "link", User::ONBOARDING_VISIBILITY
    user = User.create!(email_address: "fresh@example.com")

    assert_not user.update(visibility: User::ONBOARDING_VISIBILITY)
    assert user.update(handle: "fresh", visibility: User::ONBOARDING_VISIBILITY)
  end

  test "onboarded is every member with a handle who finished onboarding" do
    halfway = User.create!(email_address: "halfway@example.com", handle: "halfway")

    assert_includes User.onboarded, users(:every_ana)
    assert_not_includes User.onboarded, halfway
    assert_not_includes User.onboarded, users(:one)
  end

  test "visibility defaults to only me and the public column is ignored" do
    user = User.create!(email_address: "new@example.com")

    assert_equal "only_me", user.visibility
    assert_not user.email_verified?
    assert_empty user.visibility_periods
    assert_not_includes User.column_names, "public"
    assert_raises(NoMethodError) { user.public? }
    assert_raises(ActiveModel::UnknownAttributeError) { User.new(public: true) }
  end

  test "visible_to? answers for the owner, the team, other members and visitors at every level" do
    expectations = {
      "only_me" => { owner: true, team: false, other: false, visitor: false },
      "team" => { owner: true, team: true, other: false, visitor: false },
      "link" => { owner: true, team: true, other: true, visitor: true }
    }

    expectations.each do |level, expected|
      person = User.create!(email_address: "#{level}@example.com", handle: level.dasherize, visibility: level)
      viewers = { owner: person, team: users(:every_dee), other: users(:outside_eli), visitor: nil }

      expected.each { |viewer_class, allowed| assert_equal allowed, person.visible_to?(viewers[viewer_class]), "#{level} page for #{viewer_class}" }
    end
  end

  test "an unknown stored visibility is visible to no one but the owner" do
    person = users(:every_ana)
    person.update_column(:visibility, "everyone")

    assert person.visible_to?(person)
    [ users(:every_dee), users(:outside_eli), users(:one), nil ].each { |viewer| assert_not person.visible_to?(viewer) }
    assert_not_includes User.visible_to(users(:every_dee)), person
    assert_not_includes User.visible_to(nil), person
  end

  test "only me needs no handle" do
    person = users(:one)

    assert_nil person.handle
    assert_equal "only_me", person.visibility
    assert person.valid?
  end

  test "sharing with the team or the link needs a handle, since a shared page lives at it" do
    %w[team link].each do |level|
      person = users(:one)
      person.visibility = level

      assert_not person.valid?, "#{level} without a handle"
      assert_equal [ "Visibility needs a claimed link before you share your page" ], person.errors.full_messages_for(:visibility)
    end
  end

  test "a shared page cannot drop its handle" do
    person = users(:every_ana)

    assert_not person.update(handle: " ")
    assert_equal [ "Visibility needs a claimed link before you share your page" ], person.errors.full_messages_for(:visibility)
    assert_equal "ana", person.reload.handle
  end

  test "shared? is true when anyone besides the owner may open the page" do
    assert users(:every_ana).shared?
    assert users(:every_dee).shared?
    assert_not users(:every_cy).shared?

    users(:every_ana).update_column(:visibility, "everyone")
    assert_not users(:every_ana).shared?, "an unknown value shares with no one"
  end

  test "a team member needs a verified address, so an unverified @every.to viewer sees only link pages" do
    unverified = users(:every_fay)

    assert_not users(:every_dee).visible_to?(unverified)
    assert users(:every_ana).visible_to?(unverified)
  end

  test "User.visible_to lists exactly the people the viewer may open, themselves included" do
    everyone = User.all.to_a
    expected = {
      nil => %i[every_ana outside_eli every_fay],
      users(:every_dee) => %i[every_ana every_dee outside_eli every_fay],
      users(:every_cy) => %i[every_ana every_dee every_cy outside_eli every_fay],
      users(:outside_eli) => %i[every_ana outside_eli every_fay],
      users(:every_fay) => %i[every_ana outside_eli every_fay],
      users(:one) => %i[every_ana outside_eli every_fay one]
    }

    expected.each do |viewer, names|
      visible = User.visible_to(viewer)

      assert_equal names.map { |name| users(name) }.sort_by(&:id), visible.sort_by(&:id), "as #{viewer&.email_address || "a visitor"}"
      assert_equal visible.map(&:id).sort, everyone.select { |person| person.visible_to?(viewer) }.map(&:id).sort, "scope and predicate agree as #{viewer&.email_address || "a visitor"}"
    end
  end

  test "creating a user who shares opens exactly one period" do
    person = User.create!(email_address: "sharer@example.com", handle: "sharer", visibility: "link")

    assert_equal [ [ "link", nil ] ], person.visibility_periods.pluck(:level, :ends_at)
    assert_in_delta Time.current, person.visibility_periods.sole.starts_at, 5.seconds
  end

  test "every change of visibility closes the open period and opens the next, through update, update! and save" do
    person = User.create!(email_address: "switcher@example.com", handle: "switcher")
    assert_empty person.visibility_periods

    person.update(visibility: "link")
    person.update!(visibility: "team")
    person.visibility = "only_me"
    person.save!
    person.update!(visibility: "team")
    person.update!(name: "Renamed") # not a visibility change

    periods = person.visibility_periods.order(:id)
    assert_equal %w[link team team], periods.map(&:level)
    assert_equal [ false, false, true ], periods.map { |period| period.ends_at.nil? }
    assert_equal 1, periods.count { |period| period.ends_at.nil? }, "at most one period is open"
    assert_equal periods.first.ends_at, periods.second.starts_at, "each period starts where the previous ended"
  end

  test "switching to only me closes the period and opens none" do
    person = users(:every_dee)
    person.update!(visibility: "only_me")

    assert_equal 1, person.visibility_periods.count
    assert_not person.visibility_periods.exists?(ends_at: nil)
  end

  test "a failed save leaves the periods alone" do
    person = User.create!(email_address: "steady@example.com", handle: "steady", visibility: "team")

    assert_not person.update(visibility: "everyone")
    assert_equal [ "team" ], person.reload.visibility_periods.pluck(:level)
    assert_equal "team", person.visibility
  end

  test "deleting a user deletes their periods, picks, suggestions and history" do
    person = users(:every_ana)
    person.sessions.destroy_all

    person.destroy!

    %w[visibility_periods entries pick_suggestions entry_changes].each { |table| assert_equal 0, User.connection.select_value("SELECT COUNT(*) FROM #{table} WHERE user_id = #{person.id}"), table }
  end
end
