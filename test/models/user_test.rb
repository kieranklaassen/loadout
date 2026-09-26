require "test_helper"

class UserTest < ActiveSupport::TestCase
  PASSWORD = "Secret-Passw0rd" # 15 bytes, >= MINIMUM_PASSWORD_LENGTH

  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "creates a valid user with a sufficiently long password" do
    user = User.new(email_address: "new@example.com", password: PASSWORD)
    assert user.valid?, user.errors.full_messages.to_sentence
  end

  test "rejects a password shorter than MINIMUM_PASSWORD_LENGTH" do
    short = "a" * (User::MINIMUM_PASSWORD_LENGTH - 1)
    user = User.new(email_address: "short@example.com", password: short)

    refute user.valid?
    assert_includes user.errors[:password].join, "too short"
  end

  test "rejects a password over MAXIMUM_PASSWORD_BYTES to guard bcrypt truncation" do
    too_long = "a" * (User::MAXIMUM_PASSWORD_BYTES + 1)
    user = User.new(email_address: "long@example.com", password: too_long)

    refute user.valid?
    assert_includes user.errors[:password].join, "#{User::MAXIMUM_PASSWORD_BYTES} bytes"
  end
end
