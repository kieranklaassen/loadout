require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "every_member? matches the exact every.to domain only" do
    assert User.new(email_address: "ana@every.to").every_member?
    assert_not User.new(email_address: "ana@every.to.evil.com").every_member?
    assert_not User.new(email_address: "ana@sub.every.to").every_member?
    assert_not User.new(email_address: "ana@gmail.com").every_member?
  end

  test "handles are normalized, validated, unique, and not reserved" do
    user = users(:one)
    user.handle = " @Kieran "
    assert_equal "kieran", user.handle
    assert user.valid?

    user.handle = "map"
    assert_not user.valid?
    assert_includes user.errors[:handle], "is reserved"

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

  test "admin? is true for the admin column or an ADMIN_EMAILS address" do
    user = users(:one)
    assert_not user.admin?

    ENV["ADMIN_EMAILS"] = "someone@else.com, ONE@example.com"
    assert user.admin?
  ensure
    ENV.delete("ADMIN_EMAILS")
  end

  test "onboarded? needs a handle and a finished onboarding" do
    assert users(:every_ana).onboarded?
    assert_not users(:one).onboarded?
  end
end
