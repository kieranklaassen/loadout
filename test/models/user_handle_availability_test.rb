require "test_helper"

class UserHandleAvailabilityTest < ActiveSupport::TestCase
  test "a free handle is available and normalized" do
    assert_equal({ handle: "fresh", available: true, message: "loadout.every.to/fresh is yours." }, User.handle_availability(" @Fresh "))
  end

  test "blank, malformed, reserved and taken handles are not" do
    assert_equal "Pick a handle.", User.handle_availability("")[:message]
    assert_equal "Use 2 to 30 lowercase letters, numbers, and dashes.", User.handle_availability("a")[:message]
    assert_equal "Use 2 to 30 lowercase letters, numbers, and dashes.", User.handle_availability("-nope")[:message]
    assert_equal "loadout.every.to/admin is reserved.", User.handle_availability("admin")[:message]
    assert_equal "loadout.every.to/ana is taken.", User.handle_availability("ana")[:message]
  end

  test "a member's own handle is available to them" do
    assert User.handle_availability("ana", except: users(:every_ana))[:available]
    assert_not User.handle_availability("ana", except: users(:every_cy))[:available]
  end

  test "messages print the configured host" do
    Rails.configuration.x.public_base_url = "https://loadout.example.test"

    assert_equal "loadout.example.test/fresh is yours.", User.handle_availability("fresh")[:message]
    assert_equal "loadout.example.test/admin is reserved.", User.handle_availability("admin")[:message]
    assert_equal "loadout.example.test/ana is taken.", User.handle_availability("ana")[:message]
  ensure
    Rails.configuration.x.public_base_url = nil
  end
end
